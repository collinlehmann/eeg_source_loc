function [operator, info] = build_inverse(leadfield, noise_cov, cfg)
%BUILD_INVERSE Build a frozen inverse operator.
%   operator = eegsl.inverse.build_inverse(leadfield, noise_cov, cfg)
%   The returned operator is a sensor-to-source linear projection. All
%   covariance handling and regularization occur here, never in apply_inverse.
if nargin < 3, cfg = struct(); end
if isempty(leadfield), error('eegsl:Inverse:MissingLeadfield','leadfield is required.'); end
if isempty(noise_cov), error('eegsl:Inverse:MissingNoiseCov','noise_cov is required.'); end

base = eegsl.default_config();
cfg = merge_struct(base,cfg);
method = lower(char(cfg.inverse.method));
method = eegsl.inverse.method_registry(method);

[L, lfmeta] = flatten_leadfield(leadfield);
N = double(noise_cov);
if size(N,1) ~= size(N,2) || size(N,1) ~= size(L,1)
    error('eegsl:Inverse:DimensionMismatch','Noise covariance and leadfield channel counts differ.');
end
N = (N+N')/2;

switch method
    case 'wmne'
        [M, methodInfo] = build_wmne(L,N,cfg,leadfield,lfmeta);
    case {'eloreta','sloreta','lcmv'}
        error('eegsl:Inverse:NotImplemented', ...
            ['Method %s has an interface but no validated numerical implementation yet. ' ...
             'Use wmne for the dependency-free baseline.'],method);
    otherwise
        error('eegsl:Inverse:Method','Unsupported inverse method: %s.',method);
end

operator = struct();
operator.matrix = M;
operator.method = method;
operator.n_channels = size(M,2);
operator.n_source_components = size(M,1);
operator.orientation = get_orientation(leadfield);
operator.recommended_reduction = recommended_reduction(method,cfg);
operator.reference = get_reference(cfg,size(N,1));
operator.leadfield_id = get_id(leadfield,'leadfield_id');
operator.source_space_id = get_id(leadfield,'source_space_id');
operator.noise_covariance_id = eegsl.common.content_hash(N);
operator.block_sizes = lfmeta.block_sizes;
operator.inside_index = lfmeta.inside_index;
operator.empty_indices = lfmeta.empty_indices;
operator.label = get_labels(leadfield);
operator.metadata = methodInfo;
operator.apply_is_silent = true;
operator.operator_id = eegsl.common.cache_key('inverse',operator.leadfield_id, ...
    method,operator.noise_covariance_id,methodInfo.lambda,cfg.inverse.depth_exponent, ...
    cfg.inverse.regularization,eegsl.common.content_hash(operator.reference.projector), ...
    operator.block_sizes,operator.orientation,eegsl.common.content_hash(operator.label));

info = eegsl.common.provenance('inverse_operator',struct( ...
    'method',method,'orientation',operator.orientation, ...
    'recommended_reduction',operator.recommended_reduction,'n_channels',size(M,2), ...
    'n_source_components',size(M,1),'leadfield_id',operator.leadfield_id, ...
    'noise_covariance_id',operator.noise_covariance_id, ...
    'operator_id',operator.operator_id,'method_details',methodInfo, ...
    'reference',operator.reference,'block_sizes',operator.block_sizes, ...
    'label',{operator.label}));
end

function [M, out] = build_wmne(L,N,cfg,leadfield,lfmeta)
% Weighted minimum norm with configurable depth weighting.
exponent = cfg.inverse.depth_exponent;
if isempty(exponent), exponent = 0.8; end
edges = cumsum([0 lfmeta.block_sizes]);
weights = ones(1,size(L,2));
for i = 1:numel(lfmeta.block_sizes)
    cols = edges(i)+1:edges(i+1);
    f = norm(L(:,cols),'fro');
    if f <= eps, f = 1; end
    weights(cols) = f^(-double(exponent));
end
W = diag(weights);
LW = L*W;
[C, subspace, T] = covariance_inverse(N,cfg);
LT = T*LW;
lambda = cfg.inverse.lambda;
if isempty(lambda)
    lambda = choose_lambda(LT,cfg);
end
% Whitened weighted MNE: M = W*(T*LW)' / ((T*LW)*(T*LW)' + lambda*I) * T, with T*N*T' = I on the retained subspace.
A = LT*LT' + lambda*eye(size(LT,1));
M = (W * LT' / A) * T;
out = struct('lambda',lambda,'regularization',cfg.inverse.regularization, ...
    'depth_exponent',exponent,'column_weights',weights, ...
    'covariance_subspace',subspace,'method','wmne', ...
    'leadfield_components',size(L,2),'source_orientation',get_orientation(leadfield));
end

function lambda = choose_lambda(L,cfg)
% Conservative dependency-free default. Explicit lambda remains preferred.
if isfield(cfg.inverse,'lambda_default') && ~isempty(cfg.inverse.lambda_default)
    lambda = cfg.inverse.lambda_default;
else
    scale = trace(L*L')/max(1,size(L,1));
    lambda = max(eps,1e-2*max(scale,eps));
end
end

function [C, info, T] = covariance_inverse(N,cfg)
[V,D] = eig((N+N')/2);
e = real(diag(D));
tol = max(1e-12,max(abs(e)) * 1e-10);
keep = e > tol;
if ~any(keep)
    error('eegsl:Inverse:CovarianceRank','Noise covariance has no positive-rank subspace.');
end
C = V(:,keep)*diag(1./e(keep))*V(:,keep)';
T = diag(1./sqrt(e(keep)))*V(:,keep)';
info = struct('rank',sum(keep),'null_dimension',size(N,1)-sum(keep), ...
    'tolerance',tol);
end

function [L, meta] = flatten_leadfield(leadfield)
if isstruct(leadfield) && isfield(leadfield,'leadfield')
    value = leadfield.leadfield;
else
    value = leadfield;
end
if iscell(value)
    allBlocks = value;
elseif isnumeric(value) && ismatrix(value)
    orientation = get_orientation(leadfield);
    switch lower(orientation)
        case 'free'
            if mod(size(value,2),3) ~= 0
                error('eegsl:Inverse:LeadfieldColumns','Free-orientation leadfield columns must be divisible by three.');
            end
            allBlocks = arrayfun(@(k)value(:,3*k-2:3*k),1:size(value,2)/3,'UniformOutput',false);
        case {'scalar','fixed','surface-normal'}
            allBlocks = arrayfun(@(k)value(:,k),1:size(value,2),'UniformOutput',false);
        otherwise
            error('eegsl:Inverse:AmbiguousOrientation','Numeric leadfields require an explicit orientation field.');
    end
else
    error('eegsl:Inverse:LeadfieldFormat','Unsupported leadfield format.');
end
inside = get_inside(leadfield,numel(allBlocks));
emptyIndices = [];
if isempty(inside)
    emptyIndices = find(cellfun(@isempty,allBlocks));
    selected = find(~cellfun(@isempty,allBlocks));
else
    selected = find(inside);
end
blocks = allBlocks(selected);
if any(cellfun(@isempty,blocks))
    error('eegsl:Leadfield:EmptyInsideBlock','An inside source point has an empty lead-field block.');
end
if isempty(blocks), error('eegsl:Inverse:LeadfieldFormat','No non-empty inside leadfield blocks.'); end
nchan = size(blocks{1},1);
blockSizes = cellfun(@(x)size(x,2),blocks);
L = zeros(nchan,sum(blockSizes));
cursor = 1;
for k = 1:numel(blocks)
    block = double(blocks{k});
    if size(block,1) ~= nchan, error('eegsl:Inverse:LeadfieldChannels','Inconsistent leadfield channels.'); end
    stop = cursor+size(block,2)-1;
    L(:,cursor:stop) = block;
    cursor = stop+1;
end
meta = struct('n_sources',numel(blocks),'blocks',{blocks}, ...
    'block_sizes',blockSizes,'inside_index',selected,'empty_indices',emptyIndices);
end

function inside = get_inside(leadfield,nloc)
inside = [];
if isstruct(leadfield) && isfield(leadfield,'inside') && ~isempty(leadfield.inside)
    if numel(leadfield.inside) ~= nloc
        error('eegsl:Inverse:InsideShape','Leadfield inside vector does not match source locations.');
    end
    inside = logical(leadfield.inside(:));
end
end

function labels = get_labels(leadfield)
labels = {};
if isstruct(leadfield) && isfield(leadfield,'label') && ~isempty(leadfield.label)
    labels = leadfield.label(:);
end
end
function mode = recommended_reduction(method,cfg)
switch method
    case 'lcmv', mode = 'dominant';
    otherwise, mode = 'norm';
end
if isfield(cfg,'inverse') && isfield(cfg.inverse,'reduction') && ...
        ~isempty(cfg.inverse.reduction)
    mode = char(cfg.inverse.reduction);
end
end

function orientation = get_orientation(x)
if isstruct(x) && isfield(x,'orientation'), orientation = char(x.orientation); else, orientation = 'unknown'; end
end
function id = get_id(x,name)
if isstruct(x) && isfield(x,name) && ~isempty(x.(name)), id = x.(name); else, id = eegsl.common.content_hash(x); end
end
function ref = get_reference(cfg,n)
ref = struct('projector',eye(n),'rank',n);
if isfield(cfg,'reference') && isstruct(cfg.reference) && isfield(cfg.reference,'projector') && ~isempty(cfg.reference.projector)
    P = cfg.reference.projector;
    if ~isequal(size(P),[n n]), error('eegsl:Inverse:ReferenceShape','Reference projector has wrong size.'); end
    ref.projector = P;
    ref.rank = rank(P);
end
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
