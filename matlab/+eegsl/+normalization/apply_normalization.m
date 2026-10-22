function normalized = apply_normalization(op, source)
%APPLY_NORMALIZATION Apply frozen per-point normalization factors.
%   This is a silent, cheap elementwise transform. It does not estimate
%   baselines, inspect windows, or emit progress.
if nargin < 2, error('eegsl:Normalization:Data','source is required.'); end
if ~isstruct(op) || ~isfield(op,'mu') || ~isfield(op,'sigma')
    error('eegsl:Normalization:Operator','Invalid normalization operator.');
end
X = extract_samples(source);
if ~isnumeric(X), error('eegsl:Normalization:DataFormat','Source estimate must be numeric or FieldTrip-like.'); end
X = double(X);
if strcmpi(op.orientation,'free')
    if size(X,1) ~= 3*numel(op.mu)
        error('eegsl:Normalization:Dimension','Free-orientation source dimensions do not match operator.');
    end
    power = reshape(sum(reshape(X,3,[],size(X,2)).^2,1),numel(op.mu),size(X,2));
else
    if size(X,1) ~= numel(op.mu), error('eegsl:Normalization:Dimension','Source dimensions do not match operator.'); end
    power = X.^2;
end
spN = power.^op.exponent;
zplus = max((spN - op.mu)./op.sigma + op.shift,0)./op.scale;
if isstruct(source)
    normalized = source;
    normalized.avg = zplus;
    normalized.normalization_operator_id = op.operator_id;
    normalized.normalization_provenance = op.provenance;
else
    normalized = zplus;
end
end

function X = extract_samples(x)
if isnumeric(x), X = x; return; end
if isstruct(x) && isfield(x,'avg'), X = x.avg; return; end
if isstruct(x) && isfield(x,'data'), X = x.data; return; end
if isstruct(x) && isfield(x,'trial') && iscell(x.trial)
    if numel(x.trial) == 1, X = x.trial{1}; else, X = x.trial; end
else, X = []; end
end
