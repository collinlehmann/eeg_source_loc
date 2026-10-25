function normalized = apply_normalization(op, source)
%APPLY_NORMALIZATION Apply frozen factors without side effects.
if nargin < 2, error('eegsl:Normalization:Data','source is required.'); end
if ~isstruct(op) || ~isfield(op,'mu') || ~isfield(op,'sigma')
    error('eegsl:Normalization:Operator','Invalid normalization operator.');
end
if isnumeric(source)
    normalized = transform(double(source),op);
    return;
end
if ~isstruct(source)
    error('eegsl:Normalization:DataFormat','Source estimate must be numeric or FieldTrip-like.');
end
normalized = source;
if isfield(source,'trial') && iscell(source.trial)
    normalized.trial = cell(size(source.trial));
    for k = 1:numel(source.trial)
        normalized.trial{k} = transform(double(source.trial{k}),op);
    end
elseif isfield(source,'avg')
    normalized.avg = transform(double(source.avg),op);
elseif isfield(source,'data')
    normalized.data = transform(double(source.data),op);
else
    error('eegsl:Normalization:DataFormat','Expected source.trial, source.avg, or source.data.');
end
normalized.normalization_operator_id = op.operator_id;
normalized.normalization_provenance = op.provenance;
end

function zplus = transform(X,op)
if strcmpi(op.orientation,'free')
    if size(X,1) ~= 3*numel(op.mu)
        error('eegsl:Normalization:Dimension','Free-orientation source dimensions do not match operator.');
    end
    power = reshape(sum(reshape(X,3,[],size(X,2)).^2,1),numel(op.mu),size(X,2));
else
    if size(X,1) ~= numel(op.mu)
        error('eegsl:Normalization:Dimension','Source dimensions do not match operator.');
    end
    power = X.^2;
end
spN = power.^op.exponent;
zplus = max((spN-op.mu)./op.sigma+op.shift,0)./op.scale;
end
