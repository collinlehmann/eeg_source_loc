function [N, info] = estimate_noise_cov(cfg, data, leadfield, headmodel)
%ESTIMATE_NOISE_COV Estimate a frozen sensor noise covariance.
%   [N, info] = eegsl.noise.estimate_noise_cov(cfg, data, leadfield, headmodel)
%
%   cfg.paradigm is required. Task data default to the baseline route;
%   resting data default to the source-level uniform-null route. All routes
%   operate in the same reference subspace as data when cfg.reference.projector
%   is supplied. This function is precompute-only; it is never called by an
%   inverse apply path.

if nargin < 1 || isempty(cfg), cfg = struct(); end
if nargin < 2, data = []; end
if nargin < 3, leadfield = []; end
if nargin < 4, headmodel = []; end %#ok<INUSD>

base = eegsl.default_config();
cfg = merge_struct(base, cfg);
if ~isfield(cfg,'paradigm') || isempty(cfg.paradigm)
    error('eegsl:Noise:MissingParadigm', ...
        'cfg.paradigm is required; the estimator will not guess task versus resting.');
end
paradigm = lower(char(cfg.paradigm));
if ~ismember(paradigm,{'task','resting'})
    error('eegsl:Noise:InvalidParadigm','Unsupported paradigm: %s.',paradigm);
end

route = char(cfg.noise.route);
if isempty(route)
    if strcmp(paradigm,'task'), route = 'baseline'; else, route = 'uniform_null'; end
end
route = lower(route);
if strcmp(paradigm,'resting') && strcmp(route,'baseline')
    error('eegsl:Noise:RestingBaseline', ...
        'The baseline route is invalid for resting-state/spontaneous data.');
end

[R, dataInfo] = covariance_from_data(data, cfg, route);
[P, rankInfo] = reference_projector(cfg, size(R,1));
R = symmetrize(P * R * P');

switch route
    case 'baseline'
        N = baseline_covariance(data, cfg, size(R,1), P);
        routeInfo = struct('warning','');
    case 'diagonal'
        warning('eegsl:Noise:DiagonalResting', ...
            'Diagonal sensor covariance is not a uniform source-level baseline and may bias resting maps.');
        N = diag(diag(R));
        routeInfo = struct('warning','Diagonal sensor covariance is not a flat source-level baseline.');
    case 'emptyroom'
        warning('eegsl:Noise:EmptyroomResting', ...
            'Empty-room covariance captures environmental noise but not interference from other brain sources.');
        N = emptyroom_covariance(cfg, data, size(R,1), P);
        routeInfo = struct('warning','Empty-room covariance omits collective brain-source interference.');
    case 'uniform_null'
        if isempty(leadfield)
            error('eegsl:Noise:MissingLeadfield','uniform_null requires a leadfield.');
        end
        [G, geometryInfo] = eegsl.noise.geometry_term(leadfield, P);
        [N, sigmaInfo] = uniform_null_covariance(R, G, cfg, P);
        routeInfo = struct('geometry',geometryInfo,'sigma',sigmaInfo.sigma, ...
            'sigma_max',sigmaInfo.sigma_max,'lambda',sigmaInfo.lambda, ...
            'psd_projection',sigmaInfo.psd_projection);
    otherwise
        error('eegsl:Noise:Route','Unsupported noise route: %s.',route);
end

N = apply_regularization(symmetrize(N), cfg.noise.reg);
N = symmetrize(P * N * P');
if ~is_psd(N, cfg.noise.tol)
    error('eegsl:Noise:NonPSD','Estimated noise covariance is not positive semidefinite.');
end

info = eegsl.common.provenance('noise_covariance',struct( ...
    'paradigm',paradigm,'route',route,'data',dataInfo, ...
    'reference',rankInfo,'regularization',cfg.noise.reg, ...
    'rank',rankInfo.rank,'leadfield_id',leadfield_id(leadfield), ...
    'headmodel_id',eegsl.common.content_hash(headmodel), ...
    'noise_covariance_id',eegsl.common.content_hash(N)));
info.route_details = routeInfo;
end

function [R, info] = covariance_from_data(data, cfg, route)
if isstruct(data) && isfield(data,'cov') && ~isempty(data.cov) && ~strcmp(route,'baseline')
    R = double(data.cov);
elseif isstruct(data) && isfield(data,'cov') && ~isempty(data.cov) && strcmp(route,'baseline')
    % The active covariance is still useful for route provenance, while the
    % baseline covariance below is estimated from the requested window.
    R = double(data.cov);
else
    X = numeric_samples(data);
    if isempty(X), error('eegsl:Noise:MissingData','Data samples or covariance are required.'); end
    R = cov(double(X.'),1);
end
if size(R,1) ~= size(R,2), error('eegsl:Noise:CovarianceShape','Covariance must be square.'); end
R = symmetrize(R);
if any(~isfinite(R(:))), error('eegsl:Noise:CovarianceFinite','Covariance contains non-finite values.'); end
info = struct('n_channels',size(R,1),'source','data');
if isstruct(data) && isfield(data,'label'), info.labels = data.label; end
if isfield(cfg,'active_window'), info.active_window = cfg.active_window; end
end

function N = baseline_covariance(data, cfg, nchan, P)
if ~isfield(cfg,'baseline') || isempty(cfg.baseline)
    error('eegsl:Noise:MissingBaseline','cfg.baseline is required for the baseline route.');
end
X = select_window(data,cfg.baseline);
if isempty(X), error('eegsl:Noise:BaselineData','No samples found in baseline window.'); end
N = cov(double(X.'),1);
if size(N,1) ~= nchan, error('eegsl:Noise:BaselineChannels','Baseline channel count differs from active data.'); end
N = symmetrize(P*N*P');
end

function N = emptyroom_covariance(cfg, data, nchan, P)
if ~isfield(cfg,'emptyroom') || isempty(cfg.emptyroom)
    error('eegsl:Noise:MissingEmptyroom','cfg.emptyroom is required for the emptyroom route.');
end
emptyroom = cfg.emptyroom;
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

function X = select_window(data, window)
X = [];
if isnumeric(data), X = data; return; end
if ~isstruct(data), return; end
if isfield(data,'trial') && iscell(data.trial)
    for k = 1:numel(data.trial)
        trial = data.trial{k};
        if isfield(data,'time') && iscell(data.time)
            t = data.time{k};
            keep = t >= window(1) & t <= window(2);
            X = [X, trial(:,keep)]; %#ok<AGROW>
        else
            X = [X, trial]; %#ok<AGROW>
        end
    end
elseif isfield(data,'avg')
    if isfield(data,'time')
        keep = data.time >= window(1) & data.time <= window(2);
        X = data.avg(:,keep);
    else
        X = data.avg;
    end
elseif isfield(data,'data')
    X = data.data;
end
end

function X = numeric_samples(data)
if isnumeric(data), X = data; return; end
if ~isstruct(data), X = []; return; end
if isfield(data,'trial') && iscell(data.trial)
    X = [];
    for k = 1:numel(data.trial), X = [X,data.trial{k}]; %#ok<AGROW> end
elseif isfield(data,'avg'), X = data.avg;
elseif isfield(data,'data'), X = data.data;
else, X = [];
end
end

function [P, info] = reference_projector(cfg, nchan)
P = eye(nchan);
if isfield(cfg,'reference') && isstruct(cfg.reference) && isfield(cfg.reference,'projector') && ~isempty(cfg.reference.projector)
    P = double(cfg.reference.projector);
    if ~isequal(size(P),[nchan nchan])
        error('eegsl:Noise:ReferenceShape','Reference projector must be nchan-by-nchan.');
    end
end
[U,D] = eig(symmetrize(P));
keep = diag(D) > 1e-8;
if all(~keep), keep = true(nchan,1); end
[Ur,Dr] = eig(symmetrize(P*P'));
rankP = sum(diag(Dr) > 1e-8);
info = struct('projector',P,'rank',rankP,'null_dimension',nchan-rankP, ...
    'non_null_dimension',sum(keep),'projector_eigenvalues',diag(D));
end

function [N, out] = uniform_null_covariance(R,G,cfg,P)
[U,D] = eig(symmetrize(R));
e = real(diag(D));
tol = cfg.noise.tol * max(1,max(abs(e)));
keep = e > tol;
if ~any(keep)
    error('eegsl:Noise:ZeroRank','Data covariance has no numerically positive subspace.');
end
Q = U(:,keep);
Rr = symmetrize(Q'*R*Q);
Gr = symmetrize(Q'*G*Q);
Lambda = zeros(size(R));
if isfield(cfg,'noise') && isfield(cfg.noise,'lambda') && ~isempty(cfg.noise.lambda)
    Lambda = double(cfg.noise.lambda);
elseif isfield(cfg,'emptyroom') && ~isempty(cfg.emptyroom) && isfield(cfg.noise,'use_emptyroom_lambda') && cfg.noise.use_emptyroom_lambda
    Lambda = emptyroom_covariance(cfg,[],size(R,1),P);
end
Lr = symmetrize(Q'*Lambda*Q);
psd_projection = false;
if ~is_psd(Rr-Lr,cfg.noise.tol)
    if isfield(cfg.noise,'project_lambda_psd') && cfg.noise.project_lambda_psd
        Lr = project_psd(Rr);
        Lr = min_psd_component(Rr,Lr);
        psd_projection = true;
    else
        error('eegsl:Noise:LambdaNotPSD','R - Lambda is not PSD; refresh or explicitly project Lambda.');
    end
end
if isfield(cfg.noise,'sigma') && ~isempty(cfg.noise.sigma)
    sigma = double(cfg.noise.sigma);
    if ~is_psd(Rr - Lr - (sigma^2/3)*Gr,cfg.noise.tol)
        error('eegsl:Noise:SigmaNotPSD','Configured sigma violates the PSD constraint.');
    end
    sigmaMax = NaN;
else
    [sigma,sigmaMax] = find_sigma_max(Rr,Gr,Lr,cfg.noise.tol,cfg.noise.max_iterations);
end
Nr = Lr + (sigma^2/3)*Gr;
N = Q*Nr*Q';
out = struct('sigma',sigma,'sigma_max',sigmaMax,'lambda',Lambda, ...
    'rank_subspace',size(Q,2),'psd_projection',psd_projection);
end

function [sigma,sigmaMax] = find_sigma_max(R,G,L,tol,maxIter)
if norm(G,'fro') == 0, sigma = 0; sigmaMax = 0; return; end
lo = 0; hi = 1;
while is_psd(R-L-(hi^2/3)*G,tol) && hi < realmax('double')/4
    hi = hi*2;
end
for k = 1:maxIter
    mid = (lo+hi)/2;
    if is_psd(R-L-(mid^2/3)*G,tol), lo = mid; else, hi = mid; end
    if hi-lo <= max(tol,eps(max(1,hi))), break; end
end
sigma = lo; sigmaMax = lo;
end

function N = apply_regularization(N,reg)
if nargin < 2 || isempty(reg) || ~isfield(reg,'method') || strcmpi(reg.method,'none'), return; end
method = lower(char(reg.method));
value = [];
if isfield(reg,'value'), value = reg.value; end
switch method
    case 'loading'
        if isempty(value), value = 1e-6*max(1,trace(N)/size(N,1)); end
        N = N + value*eye(size(N));
    case 'shrinkage'
        if isempty(value), value = 0.05; end
        target = trace(N)/size(N,1)*eye(size(N));
        N = (1-value)*N + value*target;
    otherwise
        error('eegsl:Noise:Regularization','Unknown regularization method: %s.',method);
end
end

function tf = is_psd(A,tol)
A = symmetrize(A);
e = eig(A);
tf = min(real(e)) >= -max(tol,eps(max(1,norm(A,2))));
end
function A = project_psd(A)
[V,D] = eig(symmetrize(A));
d = max(real(diag(D)),0); A = V*diag(d)*V'; A = symmetrize(A);
end
function A = min_psd_component(R,L)
% Keep Lambda no larger than R in the Loewner sense by scaling if needed.
alpha = 1;
while alpha > 0 && ~is_psd(R-alpha*L,1e-10), alpha = alpha*0.5; end
A = alpha*L;
end
function A = symmetrize(A), A = (A+A')/2; end
function id = leadfield_id(lf)
if isempty(lf), id = ''; elseif isstruct(lf) && isfield(lf,'leadfield_id'), id = lf.leadfield_id; else, id = eegsl.common.content_hash(lf); end
end
function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    name = f{1};
    if isstruct(override.(name)) && isfield(out,name) && isstruct(out.(name))
        out.(name) = merge_struct(out.(name),override.(name));
    else, out.(name) = override.(name); end
end
end
