function result = validate_synthetic_e2e(cfg)
%VALIDATE_SYNTHETIC_E2E Deterministic, cache-aware synthetic end-to-end validation.
%   result = eegsl.validate_synthetic_e2e(cfg)
%
%   Stages (each cached under kind 'synthetic'): source_space, leadfield,
%   sources, sensor_data, noise_covariance, inverse_operator,
%   source_estimate, normalization (opt-in via cfg.normalization.enabled).
%   Requires neither FieldTrip nor external tools. Defaults filled when
%   missing: paradigm 'resting', noise.route 'diagonal', and a temporary
%   cache root. See docs/SYNTHETIC_VALIDATION.md for limitations.
if nargin < 1 || isempty(cfg), cfg = struct(); end
if ~isstruct(cfg), error('eegsl:Config:Type','cfg must be a struct.'); end
if ~isfield(cfg,'paradigm') || isempty(cfg.paradigm), cfg.paradigm = 'resting'; end
if ~isfield(cfg,'noise') || ~isfield(cfg.noise,'route') || isempty(cfg.noise.route)
    cfg.noise.route = 'diagonal';
end
if ~isfield(cfg,'cache') || ~isfield(cfg.cache,'root') || isempty(cfg.cache.root)
    cfg.cache.root = fullfile(tempdir,'eegsl_synthetic_cache');
end
cfg = eegsl.validate_config(cfg);
seed = eegsl.synthetic.resolve_seed(cfg);
nch = cfg.synthetic.n_channels;
ncomp = eegsl.synthetic.n_components(cfg);
nt = cfg.synthetic.n_samples;
S = cfg.synthetic;
infos = cell(1,8);

% 1. source space
[space, infos{1}] = eegsl.synthetic.cached_stage(cfg,'source_space',{}, ...
    @()eegsl.synthetic.build_source_space(cfg), struct('n_sources',S.n_sources,'n_channels',nch));
% 2. leadfield
[lf, infos{2}] = eegsl.synthetic.cached_stage(cfg,'leadfield',{infos{1}.key}, ...
    @()eegsl.synthetic.build_leadfield(cfg,space), struct('size',[nch ncomp]));
if ~isequal(size(lf.leadfield),[nch ncomp])
    error('eegsl:Synthetic:LeadfieldShape','Leadfield size [%s] differs from expected [%d %d].', ...
        num2str(size(lf.leadfield)),nch,ncomp);
end
% 3. sources
[src, infos{3}] = eegsl.synthetic.cached_stage(cfg,'sources',{infos{2}.key}, ...
    @()eegsl.synthetic.generate_sources(cfg,space,lf), struct('size',[ncomp nt]));
src.source = eegsl.synthetic.normalize_dimensions(src.source,ncomp,'components_by_samples','source time series');
% 4. forward + noise
[sens, infos{4}] = eegsl.synthetic.cached_stage(cfg,'sensor_data',{infos{3}.key}, ...
    @()eegsl.synthetic.project_and_noise(cfg,lf,src), struct('size',[nch nt]));
sens.noisy = eegsl.synthetic.normalize_dimensions(sens.noisy,nch,'channels_by_samples','noisy sensor data');
sens.clean = eegsl.synthetic.normalize_dimensions(sens.clean,nch,'channels_by_samples','clean sensor data');
% 5. noise covariance
labels = arrayfun(@(k)sprintf('E%d',k),1:nch,'UniformOutput',false)';
[noiseCov, infos{5}] = eegsl.synthetic.cached_stage(cfg,'noise_covariance', ...
    {infos{4}.key,cfg.noise,cfg.paradigm}, ...
    @()noise_stage(cfg,sens.noisy,labels,lf), struct('size',[nch nch]));
% 6. inverse operator
[op, infos{6}] = eegsl.synthetic.cached_stage(cfg,'inverse_operator', ...
    {infos{5}.key,cfg.inverse}, ...
    @()eegsl.inverse.build_inverse(lf,noiseCov.covariance,cfg), struct('size',[ncomp nch]));
% 7. apply inverse
[est, infos{7}] = eegsl.synthetic.cached_stage(cfg,'source_estimate', ...
    {infos{6}.key,infos{4}.key}, @()struct('estimate',eegsl.inverse.apply_inverse(op,sens.noisy)), ...
    struct('size',[ncomp nt]));
est.estimate = eegsl.synthetic.normalize_dimensions(est.estimate,ncomp,'components_by_samples','source estimate');
% 8. optional normalization
normalization = struct('enabled',false);
if cfg.normalization.enabled
    [normalization, infos{8}] = eegsl.synthetic.cached_stage(cfg,'normalization', ...
        {infos{7}.key,cfg.normalization},@()normalization_stage(cfg,est.estimate,seed), ...
        struct('size',[ncomp nt]));
    normalization.enabled = true;
else
    infos(8) = [];
end

% 9. metrics + packaging
metrics = eegsl.synthetic.compute_metrics(cfg,space,lf,src,sens,est.estimate);
cache = summarize_cache(cfg,infos);
metrics.cache = cache.summary;

result = struct();
result.synthetic = struct('seed',seed,'source_space',space,'leadfield',lf, ...
    'sources',src.source,'active_sources',src.active_sources, ...
    'sensor_clean',sens.clean,'sensor_noisy',sens.noisy,'noise_std',sens.noise_std, ...
    'sensor_data',orient(sens.noisy,S.sensor_orientation), ...
    'source_data',orient(src.source,S.source_orientation), ...
    'dimensions',struct('n_channels',nch,'n_components',ncomp,'n_samples',nt, ...
        'orientation_mode',S.orientation_mode,'canonical','rows_by_samples'));
result.inverse = struct('operator',op,'noise_covariance',noiseCov.covariance, ...
    'estimate',est.estimate,'operator_id',op.operator_id);
if cfg.normalization.enabled, result.normalization = normalization; end
result.metrics = metrics;
result.cache = cache;
result.provenance = eegsl.common.provenance('synthetic_e2e',struct( ...
    'seed',seed,'config_hash',eegsl.common.content_hash(cfg.synthetic), ...
    'leadfield_id',lf.leadfield_id,'operator_id',op.operator_id, ...
    'stage_keys',{cellfun(@(x)x.key,infos,'UniformOutput',false)}, ...
    'fieldtrip_required',false,'output_hash',eegsl.common.content_hash(struct( ...
        'sensor',sens.noisy,'estimate',est.estimate))));
end

function out = noise_stage(cfg,X,labels,lf)
w = warning('off','eegsl:Noise:DiagonalResting'); cleanup = onCleanup(@()warning(w)); %#ok<NASGU>
[N, info] = eegsl.noise.estimate_noise_cov(cfg,struct('data',X,'label',{labels}),lf,struct());
out = struct('covariance',N,'info',info);
end

function out = normalization_stage(cfg,Y,seed)
if strcmp(cfg.synthetic.orientation_mode,'free'), cfg.normalization.orientation = 'free';
else, cfg.normalization.orientation = 'scalar'; end
ws = warning('off','eegsl:Normalization:ShortWindow');
ws2 = warning('off','eegsl:Normalization:StableState');
cleanup = onCleanup(@()warning([ws ws2])); %#ok<NASGU>
st = rng; restore = onCleanup(@()rng(st)); %#ok<NASGU>
rng(double(seed),'twister');
[nop, ninfo] = eegsl.normalization.build_normalization(Y,cfg);
out = struct('operator',nop,'info',ninfo, ...
    'normalized',eegsl.normalization.apply_normalization(nop,Y));
end

function X = orient(X,orientation)
if any(strcmp(orientation,{'samples_by_channels','samples_by_components'})), X = X.'; end
end

function cache = summarize_cache(cfg,infos)
names = cellfun(@(x)x.stage,infos,'UniformOutput',false);
hits = cellfun(@(x)x.cache_hit,infos);
by = struct();
for k = 1:numel(names)
    if hits(k), by.(names{k}) = 'hit'; else, by.(names{k}) = 'miss'; end
end
cache = struct('enabled',cfg.cache.enabled,'stages',{infos}, ...
    'hits',sum(hits),'misses',sum(~hits),'by_stage',by);
cache.summary = struct('hits',cache.hits,'misses',cache.misses,'by_stage',by);
end
