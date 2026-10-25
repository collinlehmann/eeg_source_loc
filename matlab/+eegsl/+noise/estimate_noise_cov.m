function [N, info] = estimate_noise_cov(cfg, data, leadfield, headmodel)
%ESTIMATE_NOISE_COV Estimate a frozen sensor noise covariance.
%   The canonical baseline and empty-room fields are cfg.noise.baseline and
%   cfg.noise.emptyroom. Legacy top-level cfg.baseline/cfg.emptyroom inputs
%   are migrated with a warning for backward compatibility.
if nargin < 1 || isempty(cfg), cfg = struct(); end
if nargin < 2, data = []; end
if nargin < 3, leadfield = []; end
if nargin < 4, headmodel = []; end %#ok<INUSD>

[cfg, legacy] = migrate_legacy_config(cfg);
cfg = eegsl.validate_config(cfg);
paradigm = cfg.paradigm;
route = cfg.noise.route;
if isempty(route)
    if strcmp(paradigm,'task'), route = 'baseline'; else, route = 'uniform_null'; end
end

[R, dataInfo] = covariance_from_data(data, cfg, route);
[P, rankInfo] = reference_projector(cfg, size(R,1));
R = symmetrize(P * R * P');
rankScale = max(abs(eig(R)));
rank_R = rank(R,cfg.noise.tol*rankScale);
if rank_R < size(R,1) && isempty(cfg.reference.projector)
    warning('eegsl:Noise:RankDeficientNoProjector', ...
        ['R is rank-deficient (rank %d of %d) but no reference projector was supplied. ' ...
         'Supply cfg.reference.projector so N and the lead field share R''s null space ' ...
         '(spec NOISE_COVARIANCE §6).'],rank_R,size(R,1));
end

switch route
    case 'baseline'
        N = baseline_covariance(data, cfg, size(R,1), P);
        routeInfo = struct('warning','');
    case 'diagonal'
        if strcmp(paradigm,'task')
            warning('eegsl:Noise:DiagonalTask', ...
                'route is permitted but not the default for task data (default: baseline)');
        else
            warning('eegsl:Noise:DiagonalResting', ...
                'Diagonal sensor covariance is not a uniform source-level baseline and may bias resting maps.');
        end
        N = diag(diag(R));
        routeInfo = struct('warning','Diagonal sensor covariance is not a flat source-level baseline.');
    case 'emptyroom'
        if strcmp(paradigm,'task')
            warning('eegsl:Noise:EmptyroomTask', ...
                'route is permitted but not the default for task data (default: baseline)');
        else
            warning('eegsl:Noise:EmptyroomResting', ...
                'Empty-room covariance captures environmental noise but not interference from other brain sources.');
        end
        N = emptyroom_covariance(cfg, size(R,1), P);
        routeInfo = struct('warning','Empty-room covariance omits collective brain-source interference.');
    case 'uniform_null'
        if isempty(leadfield)
            error('eegsl:Noise:MissingLeadfield','uniform_null requires a leadfield.');
        end
        [G, geometryInfo] = eegsl.noise.geometry_term(leadfield, P);
        [N, sigmaInfo] = uniform_null_covariance(R, G, cfg, P);
        routeInfo = struct('geometry',geometryInfo,'sigma',sigmaInfo.sigma, ...
            'sigma_max',sigmaInfo.sigma_max,'lambda',sigmaInfo.lambda, ...
            'psd_projection',sigmaInfo.psd_projection, ...
            'min_eig_ratio',sigmaInfo.min_eig_ratio, ...
            'sigma_info',sigmaInfo.sigma_info);
    otherwise
        error('eegsl:Noise:Route','Unsupported noise route: %s.',route);
end

if strcmp(route,'uniform_null') && ~strcmpi(cfg.noise.reg.method,'none')
    warning('eegsl:Noise:RegularizationAfterUniformNull', ...
        'regularization may break the R - N >= 0 guarantee');
end
N = apply_regularization(symmetrize(N), cfg.noise.reg);
N = symmetrize(P * N * P');
dataScale = max(abs(eig(R)));
if ~is_psd(N, cfg.noise.tol, dataScale)
    error('eegsl:Noise:NonPSD','Estimated noise covariance is not positive semidefinite.');
end
if strcmp(route,'uniform_null')
    routeInfo.min_eig_ratio = min(real(eig(symmetrize(R-N))))/dataScale;
end

info = eegsl.common.provenance('noise_covariance',struct( ...
    'paradigm',paradigm,'route',route,'data',dataInfo, ...
    'reference',rankInfo,'regularization',cfg.noise.reg, ...
    'rank',rankInfo.rank,'rank_R',rank_R,'leadfield_id',leadfield_id(leadfield), ...
    'headmodel_id',stiffness_key(cfg), ...
    'noise_covariance_id',eegsl.common.content_hash(N), ...
    'configuration',cfg,'legacy_migration',legacy));
info.route_details = routeInfo;
end

function [cfg, legacy] = migrate_legacy_config(cfg)
%MIGRATE_LEGACY_CONFIG Move pre-contract top-level covariance fields.
legacy = struct('baseline',false,'emptyroom',false);
if ~isstruct(cfg), error('eegsl:Noise:ConfigType','cfg must be a struct.'); end
if ~isfield(cfg,'noise') || ~isstruct(cfg.noise), cfg.noise = struct(); end
if isfield(cfg,'baseline') && ~isempty(cfg.baseline) && ...
        (~isfield(cfg.noise,'baseline') || isempty(cfg.noise.baseline))
    cfg.noise.baseline = cfg.baseline;
    legacy.baseline = true;
    warning('eegsl:Config:LegacyBaseline', ...
        'cfg.baseline is deprecated; use cfg.noise.baseline.');
end
if isfield(cfg,'emptyroom') && ~isempty(cfg.emptyroom) && ...
        (~isfield(cfg.noise,'emptyroom') || isempty(cfg.noise.emptyroom))
    cfg.noise.emptyroom = cfg.emptyroom;
    legacy.emptyroom = true;
    warning('eegsl:Config:LegacyEmptyroom', ...
        'cfg.emptyroom is deprecated; use cfg.noise.emptyroom.');
end
end

function [R, info] = covariance_from_data(data, cfg, route)
if isstruct(data) && isfield(data,'cov') && ~isempty(data.cov)
    R = double(data.cov);
else
    X = numeric_samples(data);
    if isempty(X), error('eegsl:Noise:MissingData','Data samples or covariance are required.'); end
    R = cov(double(X.'),1);
end
if size(R,1) ~= size(R,2), error('eegsl:Noise:CovarianceShape','Covariance must be square.'); end
R = symmetrize(R);
if any(~isfinite(R(:))), error('eegsl:Noise:CovarianceFinite','Covariance contains non-finite values.'); end
info = struct('n_channels',size(R,1),'source','data','route',route);
if isstruct(data) && isfield(data,'label'), info.labels = data.label; end
if isfield(cfg,'inverse') && isfield(cfg.inverse,'representative_window')
    info.active_window = cfg.inverse.representative_window;
end
end

function N = baseline_covariance(data, cfg, nchan, P)
window = cfg.noise.baseline;
[X,hasTime] = select_window(data,window);
if ~hasTime
    error('eegsl:Noise:BaselineNoTime', ...
        'The baseline route requires per-sample time information.');
end
if isempty(X), error('eegsl:Noise:BaselineData','No samples found in baseline window.'); end
N = cov(double(X.'),1);
if size(N,1) ~= nchan, error('eegsl:Noise:BaselineChannels','Baseline channel count differs from active data.'); end
N = symmetrize(P*N*P');
end

function N = emptyroom_covariance(cfg, nchan, P)
emptyroom = cfg.noise.emptyroom;
if isempty(emptyroom)
    error('eegsl:Noise:MissingEmptyroom','cfg.noise.emptyroom is required for the emptyroom route.');
end
if isnumeric(emptyroom)
    N = double(emptyroom);
elseif isstruct(emptyroom) && isfield(emptyroom,'cov') && ~isempty(emptyroom.cov)
    N = double(emptyroom.cov);
else
    X = numeric_samples(emptyroom);
    if isempty(X), error('eegsl:Noise:EmptyroomData','No empty-room samples found.'); end
    N = cov(double(X.'),1);
end
if ~isequal(size(N),[nchan nchan])
    error('eegsl:Noise:EmptyroomChannels','Empty-room covariance dimensions do not match data.');
end
N = symmetrize(P*N*P');
end

function [X,hasTime] = select_window(data, window)
X = []; hasTime = false;
if isnumeric(data), X = data; return; end
if ~isstruct(data), return; end
if isfield(data,'trial') && iscell(data.trial)
    hasTime = isfield(data,'time') && iscell(data.time) && ...
        numel(data.time) == numel(data.trial);
    for k = 1:numel(data.trial)
        trial = data.trial{k};
        if hasTime
            t = data.time{k};
            if numel(t) ~= size(trial,2), error('eegsl:Noise:TimeShape','Time and trial samples differ.'); end
            keep = t >= window(1) & t <= window(2);
            X = [X, trial(:,keep)]; %#ok<AGROW>
        else
            X = [X, trial]; %#ok<AGROW>
        end
    end
elseif isfield(data,'avg')
    if isfield(data,'time')
        if numel(data.time) ~= size(data.avg,2), error('eegsl:Noise:TimeShape','Time and average samples differ.'); end
        keep = data.time >= window(1) & data.time <= window(2);
        X = data.avg(:,keep);
        hasTime = true;
    else
        X = data.avg;
    end
elseif isfield(data,'data')
    if isfield(data,'time')
        if numel(data.time) ~= size(data.data,2), error('eegsl:Noise:TimeShape','Time and data samples differ.'); end
        keep = data.time >= window(1) & data.time <= window(2);
        X = data.data(:,keep);
        hasTime = true;
    else
        X = data.data;
    end
end
end

function X = numeric_samples(data)
if isnumeric(data), X = data; return; end
if ~isstruct(data), X = []; return; end
if isfield(data,'trial') && iscell(data.trial)
    X = [];
    for k = 1:numel(data.trial), X = [X,data.trial{k}]; end %#ok<AGROW>
elseif isfield(data,'avg'), X = data.avg;
elseif isfield(data,'data'), X = data.data;
else, X = [];
end
end

function [P, info] = reference_projector(cfg, nchan)
P = eye(nchan);
if isfield(cfg,'reference') && isfield(cfg.reference,'projector') && ~isempty(cfg.reference.projector)
    P = double(cfg.reference.projector);
    if ~isequal(size(P),[nchan nchan])
        error('eegsl:Noise:ReferenceShape','Reference projector must be nchan-by-nchan.');
    end
end
[~,D] = eig(symmetrize(P));
[~,Dr] = eig(symmetrize(P*P'));
rankP = sum(diag(Dr) > cfg.reference.rank_tolerance);
info = struct('name',cfg.reference.name,'projector',P,'rank',rankP, ...
    'null_dimension',nchan-rankP,'non_null_dimension',rankP, ...
    'projector_eigenvalues',diag(D),'rank_tolerance',cfg.reference.rank_tolerance);
end

function [N, out] = uniform_null_covariance(R,G,cfg,P)
[U,D] = eig(symmetrize(R));
e = real(diag(D));
tol = cfg.noise.tol * max(abs(e));
keep = e > tol;
if ~any(keep), error('eegsl:Noise:ZeroRank','Data covariance has no numerically positive subspace.'); end
Q = U(:,keep);
Rr = symmetrize(Q'*R*Q);
Gr = symmetrize(Q'*G*Q);
Lambda = zeros(size(R));
if ~isempty(cfg.noise.lambda), Lambda = double(cfg.noise.lambda); end
Lr = symmetrize(Q'*Lambda*Q);
psd_projection = false;
scale = max(abs(eig(Rr)));
if ~is_psd(Rr-Lr,cfg.noise.tol,scale)
    if cfg.noise.project_lambda_psd
    Lr = min_psd_component(Rr,project_psd(Lr),cfg.noise.tol,scale);
        psd_projection = true;
    else
        error('eegsl:Noise:LambdaNotPSD','R - Lambda is not PSD; refresh or explicitly project Lambda.');
    end
end
if ~isempty(cfg.noise.sigma)
    sigma = double(cfg.noise.sigma);
    if ~is_psd(Rr-Lr-(sigma^2/3)*Gr,cfg.noise.tol,scale)
        error('eegsl:Noise:SigmaNotPSD','Configured sigma violates the PSD constraint.');
    end
    sigmaMax = NaN;
    sigmaInfo = struct('method','user_supplied','s',sigma^2/3, ...
        'relative_tolerance',cfg.noise.tol,'scale',scale,'min_eig_ratio', ...
        min(real(eig(symmetrize(Rr-Lr-(sigma^2/3)*Gr))))/scale, ...
        'retained_dimension',size(Rr,1));
else
    [sigmaMax,sigmaInfo] = eegsl.noise.sigma_max(Rr,Gr,Lr, ...
        struct('tol',cfg.noise.tol,'method',cfg.noise.sigma_method, ...
        'max_iterations',cfg.noise.max_iterations));
    sigma = sigmaMax;
    sigmaMax = sigma;
end
N = Q*(Lr+(sigma^2/3)*Gr)*Q';
ratio = min(real(eig(symmetrize(Rr-Q'*N*Q))))/scale;
if ratio < -10*cfg.noise.tol
    error('eegsl:Noise:SigmaMaxViolation', ...
        'Uniform-null covariance violates the relative PSD bound (minimum eigenvalue ratio %g).',ratio);
end
sigmaInfo.min_eig_ratio = ratio;
out = struct('sigma',sigma,'sigma_max',sigmaMax,'lambda',Lambda, ...
    'rank_subspace',size(Q,2),'psd_projection',psd_projection, ...
    'min_eig_ratio',ratio,'sigma_info',sigmaInfo);
end

function N = apply_regularization(N,reg)
if nargin < 2 || isempty(reg) || strcmpi(reg.method,'none'), return; end
method = lower(char(reg.method)); value = reg.value;
if isempty(value), value = 1e-6*max(1,trace(N)/size(N,1)); end
switch method
    case 'loading', N = N + value*eye(size(N));
    case 'shrinkage', N = (1-value)*N + value*(trace(N)/size(N,1))*eye(size(N));
    otherwise, error('eegsl:Noise:Regularization','Unknown regularization method: %s.',method);
end
end
function tf = is_psd(A,tol,scale), A=symmetrize(A); tf=min(real(eig(A))) >= -tol*scale; end
function A = project_psd(A), [V,D]=eig(symmetrize(A)); A=symmetrize(V*diag(max(real(diag(D)),0))*V'); end
function A = min_psd_component(R,L,tol,scale)
alpha=1; while alpha > 0 && ~is_psd(R-alpha*L,tol,scale), alpha=alpha*0.5; end; A=alpha*L;
end
function A = symmetrize(A), A=(A+A')/2; end
function id = leadfield_id(lf)
if isempty(lf), id=''; elseif isstruct(lf)&&isfield(lf,'leadfield_id'), id=lf.leadfield_id; else, id=eegsl.common.content_hash(lf); end
end
function id = stiffness_key(cfg)
id = '';
if isfield(cfg,'forward') && isfield(cfg.forward,'cache_keys') && ...
        isstruct(cfg.forward.cache_keys) && isfield(cfg.forward.cache_keys,'stiffness_key')
    id = cfg.forward.cache_keys.stiffness_key;
end
end
