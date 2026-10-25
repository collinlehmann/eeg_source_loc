function [op, info] = build_normalization(background, cfg)
%BUILD_NORMALIZATION Estimate frozen per-point normalization factors.
%   background is source-space activity with rows as source points and
%   columns as time samples. For free orientation, provide 3*N rows and
%   set cfg.normalization.orientation = 'free'. Scalar rows are accepted.
%   This function is precompute-only and may warn for short/averaged windows.
if nargin < 2, cfg = struct(); end
base = eegsl.default_config();
cfg = merge_struct(base,cfg);
if ~isfield(cfg,'normalization') || ~isstruct(cfg.normalization)
    error('eegsl:Normalization:Config','cfg.normalization is required.');
end
ncfg = cfg.normalization;
if ~isfield(ncfg,'enabled') || ~ncfg.enabled
    error('eegsl:Normalization:Disabled','Normalization is opt-in; set cfg.normalization.enabled = true.');
end
X = extract_samples(background);
if isempty(X) || ~isnumeric(X)
    error('eegsl:Normalization:Data','Background source estimates must be numeric.');
end
X = double(X);
if ndims(X) ~= 2, error('eegsl:Normalization:Shape','Background must be points/components by time.'); end
orientation = get_or(ncfg,'orientation','free');
orientation = lower(char(orientation));
if strcmp(orientation,'free')
    if mod(size(X,1),3) ~= 0
        error('eegsl:Normalization:FreeOrientation','Free-orientation rows must be divisible by 3.');
    end
    power = sum(reshape(X,3,[],size(X,2)).^2,1);
    power = reshape(power,[],size(X,2));
else
    power = X.^2;
end
spN = power.^double(get_or(ncfg,'exponent',0.2887));
ns = max(1,round(get_or(ncfg,'subsamples',20)));
nsz = get_or(ncfg,'subsample_size',[]);
if isempty(nsz), nsz = min(size(spN,2),max(1000,round(size(spN,2)/2))); end
nsz = min(size(spN,2),max(1,round(nsz)));
mu = zeros(size(spN,1),1); sigma = zeros(size(spN,1),1);
muSamples = zeros(size(spN,1),ns); sigmaSamples = zeros(size(spN,1),ns);
rngState = rng; cleanup = onCleanup(@()rng(rngState)); %#ok<NASGU>
for k = 1:ns
    idx = randperm(size(spN,2),nsz);
    sample = spN(:,idx);
    for p = 1:size(sample,1)
        values = sort(sample(p,:));
        modeEstimate = left_mode(values);
        below = values(values < modeEstimate);
        if numel(below) < 3
            below = values(values <= modeEstimate);
        end
        if isempty(below), below = values; end
        muSamples(p,k) = modeEstimate;
        sigmaSamples(p,k) = mad_compat(below);
    end
end
mu = median(muSamples,2);
sigma = median(sigmaSamples,2);
floorValue = get_or(ncfg,'scale_floor',eps);
zeroScale = sigma <= floorValue | ~isfinite(sigma);
sigma(zeroScale) = 1;

stableFraction = max(abs(spN - mu) <= max(sigma,eps),[],2);
shortWindow = size(X,2) < get_or(ncfg,'minimum_samples',1000);
stableLimit = get_or(ncfg,'stable_state_fraction_warning',0.5);
stableWarning = any(stableFraction > stableLimit);
if shortWindow
    warning('eegsl:Normalization:ShortWindow', ...
        'Normalization background has fewer than the recommended number of samples.');
end
if stableWarning
    warning('eegsl:Normalization:StableState', ...
        'Some source points may remain in a stable state too long for robust background estimation.');
end

op = struct();
op.mu = mu;
op.sigma = sigma;
op.exponent = double(get_or(ncfg,'exponent',0.2887));
op.shift = double(get_or(ncfg,'shift',3));
op.scale = double(get_or(ncfg,'scale',3));
op.orientation = orientation;
op.n_points = size(spN,1);
op.n_samples = size(X,2);
op.subsamples = ns;
op.subsample_size = nsz;
op.zero_scale_points = find(zeroScale);
op.baseline_window = get_or(ncfg,'window',[]);
op.provenance = eegsl.common.provenance('normalization',struct( ...
    'n_points',op.n_points,'n_samples',op.n_samples, ...
    'orientation',orientation,'subsamples',ns,'subsample_size',nsz, ...
    'short_window',shortWindow,'stable_state_warning',stableWarning));
op.operator_id = eegsl.common.cache_key('normalization',mu,sigma,op.exponent, ...
    op.shift,op.scale,orientation);

info = op.provenance;
info.operator_id = op.operator_id;
info.stable_fraction = stableFraction;
info.zero_scale_points = op.zero_scale_points;
end

function X = extract_samples(x)
if isnumeric(x), X = x; return; end
if isstruct(x) && isfield(x,'data'), X = x.data; return; end
if isstruct(x) && isfield(x,'avg'), X = x.avg; return; end
if isstruct(x) && isfield(x,'trial') && iscell(x.trial)
    X = [];
    for k = 1:numel(x.trial), X = [X,double(x.trial{k})]; end %#ok<AGROW>
else, X = []; end
end

function m = left_mode(x)
% Histogram mode estimate over the lower/background half of the sample.
x = x(isfinite(x));
if isempty(x), m = 0; return; end
x = sort(x); n = numel(x); lower = x(1:max(3,ceil(n/2)));
if max(lower) == min(lower), m = lower(1); return; end
nbins = min(64,max(8,ceil(sqrt(numel(lower)))));
edges = linspace(min(lower),max(lower),nbins+1);
counts = histcounts(lower,edges);
[~,bin] = max(counts);
m = (edges(bin)+edges(bin+1))/2;
end

function m = mad_compat(x)
x = x(isfinite(x));
if isempty(x), m = 0; return; end
med = median(x);
m = median(abs(x-med));
end

function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
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
