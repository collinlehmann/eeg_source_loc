function X = normalize_dimensions(X, nRows, orientation, name)
%NORMALIZE_DIMENSIONS Adapt a matrix to canonical rows-by-samples orientation.
%   orientation: 'rows_by_samples' (canonical: channels/components by
%   samples) or 'samples_by_rows' (transposed). Errors with
%   eegsl:Synthetic:* when the shape cannot match nRows.
if nargin < 4, name = 'data'; end
if ~(isnumeric(X) && ismatrix(X) && ~isempty(X))
    error('eegsl:Synthetic:DataType','%s must be a non-empty numeric matrix.',name);
end
switch orientation
    case {'rows_by_samples','channels_by_samples','components_by_samples'}
    case {'samples_by_rows','samples_by_channels','samples_by_components'}
        X = X.';
    otherwise
        error('eegsl:Synthetic:Orientation','Unsupported orientation "%s" for %s.',char(orientation),name);
end
if size(X,1) ~= nRows
    error('eegsl:Synthetic:DimensionMismatch','%s has %d rows after orientation handling; expected %d.', ...
        name,size(X,1),nRows);
end
end
