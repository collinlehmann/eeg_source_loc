function result = run_synthetic_validation(cfg)
%RUN_SYNTHETIC_VALIDATION Deterministic synthetic end-to-end validation flow.
if nargin < 1, cfg = struct(); end
cfg = eegsl.validate_config(cfg);
if ~ismember(cfg.paradigm,{'task','resting'})
    error('eegsl:Pipeline:SyntheticParadigm','cfg.paradigm must be task or resting.');
end

seed = resolve_seed(cfg);
rngState = rng; cleanup = onCleanup(@()rng(rngState)); %#ok<NASGU>
rng(seed,'twister');

[geometry, gInfo] = cached_stage(cfg,'geometry', ...
    {cfg.synthetic.n_channels,cfg.synthetic.n_sources,cfg.synthetic.deep_source_index}, ...
    @()build_geometry(cfg));

[leadfield, lfInfo] = cached_stage(cfg,'leadfield', ...
    {geometry.source.source_space_id,eegsl.common.content_hash(geometry.electrodes)}, ...
    @()build_analytic_leadfield(cfg,geometry));

[truth, tInfo] = cached_stage(cfg,'source_truth', ...
    {leadfield.leadfield_id,cfg.synthetic.active_sources,cfg.synthetic.n_time}, ...
    @()build_source_truth(cfg,geometry,leadfield));

[sensor, sInfo] = cached_stage(cfg,'sensor_data', ...
    {leadfield.leadfield_id,eegsl.common.content_hash(truth.source_internal),cfg.synthetic.noise_std,cfg.synthetic.snr_db}, ...
    @()project_sensor_data(cfg,leadfield,truth));

noiseInput = struct('data',sensor.noisy_internal,'label',{geometry.electrodes.label});
[noiseCov, nInfo] = cached_stage(cfg,'noise_covariance', ...
    {eegsl.common.content_hash(sensor.noisy_internal),leadfield.leadfield_id,cfg.noise.route}, ...
    @()eegsl.noise.estimate_noise_cov(cfg,noiseInput,leadfield,struct()));

[inverse, iInfo] = cached_stage(cfg,'inverse_operator', ...
    {leadfield.leadfield_id,eegsl.common.content_hash(noiseCov)}, ...
    @()eegsl.inverse.build_inverse(leadfield,noiseCov,cfg));

[estimate, eInfo] = cached_stage(cfg,'source_estimate', ...
    {inverse.operator_id,eegsl.common.content_hash(sensor.noisy_internal)}, ...
    @()apply_inverse_stage(cfg,inverse,sensor));

normalization = struct('enabled',false,'applied',false,'operator',[],'normalized',[],'info',[]);
if cfg.synthetic.normalization.enabled
    if ~cfg.normalization.enabled
        error('eegsl:Pipeline:SyntheticNormalizationConfig', ...
            'Set cfg.normalization.enabled=true when synthetic.normalization.enabled=true.');
    end
    [normalization, normInfo] = cached_stage(cfg,'normalization', ...
        {inverse.operator_id,eegsl.common.content_hash(estimate.estimate_internal)}, ...
        @()normalization_stage(cfg,estimate));
else
    normInfo = stage_info('normalization','skipped',false,'skipped');
end

metrics = compute_metrics(geometry,leadfield,truth,sensor,estimate,cfg);
cache = summarize_cache(cfg,{gInfo,lfInfo,tInfo,sInfo,nInfo,iInfo,eInfo,normInfo});

result = struct();
result.seed = seed;
result.config = cfg;
result.geometry = geometry;
result.leadfield = leadfield;
result.truth = truth;
result.sensor = sensor;
result.noise_covariance = noiseCov;
result.inverse = inverse;
result.estimate = estimate;
result.normalization = normalization;
result.metrics = metrics;
result.cache = cache;
result.dimensions = struct( ...
    'n_channels',cfg.synthetic.n_channels, ...
    'n_sources',cfg.synthetic.n_sources, ...
    'n_components',3*cfg.synthetic.n_sources, ...
    'n_time',cfg.synthetic.n_time);
result.provenance = eegsl.common.provenance('synthetic_validation',struct( ...
    'seed',seed,'cache',cache,'metrics',metrics, ...
    'leadfield_id',leadfield.leadfield_id,'operator_id',inverse.operator_id, ...
    'noise_covariance_id',eegsl.common.content_hash(noiseCov)));
end

function seed = resolve_seed(cfg)
seed = cfg.seed;
if isfield(cfg,'synthetic') && isfield(cfg.synthetic,'seed') && ~isempty(cfg.synthetic.seed)
    seed = cfg.synthetic.seed;
end
if isempty(seed), seed = 1; end
end

function [artifact, info] = cached_stage(cfg, stageName, keyParts, computeFcn)
if nargin < 4 || ~isa(computeFcn,'function_handle')
    error('eegsl:Pipeline:SyntheticStageFunction','A compute function is required.');
end
key = eegsl.common.cache_key('synthetic',cfg.synthetic.cache_prefix,stageName,keyParts{:});
kind = 'synthetic';
if cfg.cache.enabled && eegsl.common.has_artifact(cfg,kind,key)
    [artifact, metadata] = eegsl.common.load_artifact(cfg,kind,key);
    info = stage_info(stageName,key,true,'',metadata);
    return;
end
artifact = computeFcn();
metadata = struct('stage',stageName,'seed',resolve_seed(cfg), ...
    'stage_provenance',eegsl.common.provenance(stageName,struct('key',key)));
if cfg.cache.enabled && ~cfg.cache.read_only
    eegsl.common.save_artifact(cfg,kind,key,artifact,metadata);
end
info = stage_info(stageName,key,false,'',metadata);
end

function info = stage_info(stageName,key,hit,status,metadata)
if nargin < 4 || isempty(status), status = 'ok'; end
if nargin < 5, metadata = struct(); end
info = struct('stage',stageName,'key',key,'cache_hit',logical(hit), ...
    'status',status,'metadata',metadata);
end

function [geometry, p] = build_geometry(cfg)
nchan = cfg.synthetic.n_channels;
nsrc = cfg.synthetic.n_sources;
deepIdx = cfg.synthetic.deep_source_index;

elecPos = sphere_points(nchan,1.1);
labels = arrayfun(@(k)sprintf('E%d',k),1:nchan,'UniformOutput',false)';
electrodes = struct('chanpos',elecPos,'label',{labels},'unit','au');

srcPos = sphere_points(nsrc,0.75);
depthScale = linspace(0.9,0.55,nsrc)';
srcPos = srcPos .* depthScale;
srcPos(deepIdx,:) = srcPos(deepIdx,:) .* 0.35;
sourcemodel = struct();
sourcemodel.pos = srcPos;
sourcemodel.inside = true(nsrc,1);
sourcemodel.outside = false(nsrc,1);
sourcemodel.unit = 'au';
sourcemodel.orientation = 'free';
sourcemodel.label = arrayfun(@(k)sprintf('S%d',k),1:nsrc,'UniformOutput',false)';
sourcemodel.source_space_id = eegsl.common.cache_key('synthetic_source_space',srcPos,deepIdx);

geometry = struct('electrodes',electrodes,'source',sourcemodel);
p = eegsl.common.provenance('synthetic_geometry',struct( ...
    'n_channels',nchan,'n_sources',nsrc,'deep_source_index',deepIdx, ...
    'source_space_id',sourcemodel.source_space_id));
geometry.provenance = p;
end

function [leadfield, p] = build_analytic_leadfield(~, geometry)
chan = geometry.electrodes.chanpos;
src = geometry.source.pos;
nchan = size(chan,1);
nsrc = size(src,1);
L = zeros(nchan,3*nsrc);
for j = 1:nsrc
    v = chan - src(j,:);
    r = sqrt(sum(v.^2,2));
    if any(r <= eps)
        error('eegsl:Pipeline:SyntheticGeometry','Source and electrode positions must not coincide.');
    end
    u = v ./ r;
    gain = 1 ./ (r.^2 + 0.05);
    cols = gain .* u;
    colNorm = sqrt(sum(cols.^2,1));
    colNorm(colNorm <= eps) = 1;
    cols = cols ./ colNorm;
    L(:,(3*j-2):(3*j)) = cols;
end

leadfield = struct();
leadfield.leadfield = L;
leadfield.orientation = 'free';
leadfield.source_space_id = geometry.source.source_space_id;
leadfield.leadfield_id = eegsl.common.cache_key('synthetic_leadfield',L,geometry.source.source_space_id);
p = eegsl.common.provenance('synthetic_leadfield',struct( ...
    'n_channels',size(L,1),'n_source_components',size(L,2), ...
    'leadfield_id',leadfield.leadfield_id,'source_space_id',leadfield.source_space_id));
leadfield.provenance = p;
end

function [truth, p] = build_source_truth(cfg, geometry, leadfield)
ncomp = size(leadfield.leadfield,2);
nt = cfg.synthetic.n_time;
t = linspace(0,1,nt);
source = zeros(ncomp,nt);
active = cfg.synthetic.active_sources;
if ~ismember(cfg.synthetic.deep_source_index,active)
    active = unique([active cfg.synthetic.deep_source_index]);
end
for k = 1:numel(active)
    idx = active(k);
    c = 3*(idx-1)+1;
    freq = 6 + 2*k;
    phase = (k-1)*pi/7;
    amp = 1.0 - 0.1*(k-1);
    if idx == cfg.synthetic.deep_source_index, amp = amp * 1.3; end
    source(c,:) = amp*sin(2*pi*freq*t + phase);
    source(c+1,:) = 0.6*amp*cos(2*pi*(freq+1)*t + phase/2);
end
truth = struct();
truth.time = t;
truth.active_sources = active;
truth.deep_source_index = cfg.synthetic.deep_source_index;
truth.source_internal = source;
truth.source = orient_source(source,cfg.synthetic.source_orientation);
truth.reduced = eegsl.inverse.reduce_source(source,'norm');
truth.source_positions = geometry.source.pos;
p = eegsl.common.provenance('synthetic_source_truth',struct( ...
    'n_components',ncomp,'n_time',nt,'active_sources',active, ...
    'deep_source_index',cfg.synthetic.deep_source_index));
truth.provenance = p;
end

function [sensor, p] = project_sensor_data(cfg, leadfield, truth)
L = leadfield.leadfield;
X = L * truth.source_internal;
if ~isempty(cfg.synthetic.snr_db)
    signalStd = std(X(:));
    noiseStd = signalStd / (10^(cfg.synthetic.snr_db/20));
else
    noiseStd = cfg.synthetic.noise_std;
end
noise = noiseStd * randn(size(X));
Xn = X + noise;
sensor = struct();
sensor.clean_internal = X;
sensor.noisy_internal = Xn;
sensor.noise_internal = noise;
sensor.noise_std = noiseStd;
sensor.clean = orient_sensor(X,cfg.synthetic.sensor_orientation);
sensor.noisy = orient_sensor(Xn,cfg.synthetic.sensor_orientation);
sensor.noise = orient_sensor(noise,cfg.synthetic.sensor_orientation);
p = eegsl.common.provenance('synthetic_sensor_projection',struct( ...
    'noise_std',noiseStd,'snr_db',cfg.synthetic.snr_db, ...
    'n_channels',size(X,1),'n_time',size(X,2)));
sensor.provenance = p;
end

function [estimate, p] = apply_inverse_stage(cfg, inverse, sensor)
X = sensor.noisy_internal;
if size(X,1) ~= inverse.n_channels
    error('eegsl:Pipeline:SyntheticSensorDimension', ...
        'Sensor matrix must be n_channels-by-n_time after normalization.');
end
Y = eegsl.inverse.apply_inverse(inverse,X);
estimate = struct();
estimate.estimate_internal = Y;
estimate.estimate = orient_source(Y,cfg.synthetic.source_orientation);
estimate.reduced = eegsl.inverse.reduce_source(Y,'norm');
p = eegsl.common.provenance('synthetic_source_estimate',struct( ...
    'operator_id',inverse.operator_id,'n_components',size(Y,1),'n_time',size(Y,2)));
estimate.provenance = p;
end

function [normalization, p] = normalization_stage(cfg, estimate)
[op, info] = eegsl.normalization.build_normalization(estimate.estimate_internal,cfg);
normalized = eegsl.normalization.apply_normalization(op,estimate.estimate_internal);
normalization = struct('enabled',true,'applied',true,'operator',op,'normalized',normalized,'info',info);
p = eegsl.common.provenance('synthetic_normalization',struct('operator_id',op.operator_id));
normalization.provenance = p;
end

function metrics = compute_metrics(geometry, leadfield, truth, sensor, estimate, cfg)
L = leadfield.leadfield;
Strue = truth.source_internal;
Sest = estimate.estimate_internal;
Xclean = sensor.clean_internal;
Xrecon = L * Sest;
sensorErr = norm(Xrecon - Xclean,'fro') / max(eps,norm(Xclean,'fro'));

trueR = truth.reduced;
estR = estimate.reduced;
active = truth.active_sources;
corrVals = zeros(numel(active),1);
locErr = zeros(numel(active),1);
for k = 1:numel(active)
    idx = active(k);
    corrVals(k) = row_corr(trueR(idx,:),estR(idx,:));
    [~,tp] = max(abs(trueR(idx,:)));
    [~,best] = max(estR(:,tp));
    locErr(k) = norm(geometry.source.pos(best,:) - geometry.source.pos(idx,:));
end
deepIdx = cfg.synthetic.deep_source_index;
deepMask = active == deepIdx;
if any(deepMask)
    deepCorr = corrVals(find(deepMask,1,'first'));
    deepLoc = locErr(find(deepMask,1,'first'));
else
    deepCorr = NaN;
    deepLoc = NaN;
end
metrics = struct();
metrics.sensor_reconstruction_error = sensorErr;
metrics.source_correlation_mean = mean(corrVals);
metrics.source_correlation_active = corrVals;
metrics.localization_error_active = locErr;
metrics.localization_error_mean = mean(locErr);
metrics.deep_source_correlation = deepCorr;
metrics.deep_source_localization_error = deepLoc;
metrics.output_hash = eegsl.common.content_hash(struct('sensor',sensor.noisy_internal,'estimate',Sest));
end

function c = row_corr(a,b)
a = double(a(:)); b = double(b(:));
a = a - mean(a); b = b - mean(b);
den = norm(a) * norm(b);
if den <= eps, c = 0; else, c = (a'*b) / den; end
end

function cache = summarize_cache(cfg, stageInfo)
cache = struct('enabled',cfg.cache.enabled,'hits',0,'misses',0,'stages',{stageInfo});
for k = 1:numel(stageInfo)
    if stageInfo{k}.cache_hit
        cache.hits = cache.hits + 1;
    else
        if ~strcmp(stageInfo{k}.status,'skipped')
            cache.misses = cache.misses + 1;
        end
    end
end
end

function X = orient_sensor(Xinternal,orientation)
switch lower(char(orientation))
    case 'channels_by_samples'
        X = Xinternal;
    case 'samples_by_channels'
        X = Xinternal.';
    otherwise
        error('eegsl:Pipeline:SyntheticOrientation', ...
            'Unsupported synthetic.sensor_orientation: %s',char(orientation));
end
end

function X = orient_source(Xinternal,orientation)
switch lower(char(orientation))
    case 'components_by_samples'
        X = Xinternal;
    case 'samples_by_components'
        X = Xinternal.';
    otherwise
        error('eegsl:Pipeline:SyntheticOrientation', ...
            'Unsupported synthetic.source_orientation: %s',char(orientation));
end
end

function p = sphere_points(n,radius)
if n < 1, error('eegsl:Pipeline:SyntheticCount','Point count must be positive.'); end
k = (0:n-1)';
phi = (1+sqrt(5))/2;
theta = 2*pi*k/phi;
z = 1 - 2*(k+0.5)/n;
xy = sqrt(max(0,1-z.^2));
p = [xy.*cos(theta), xy.*sin(theta), z];
p = radius .* p;
end
