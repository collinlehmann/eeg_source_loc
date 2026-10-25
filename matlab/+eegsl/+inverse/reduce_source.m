function [scalar, mode] = reduce_source(source3d, mode)
%REDUCE_SOURCE Reduce free-orientation estimates without changing apply_inverse.
%   source3d may be components-by-time or a FieldTrip-like source result.
if nargin < 2 || isempty(mode), mode = 'norm'; end
mode = lower(char(mode));
if strcmp(mode,'dominant')
    error('eegsl:Inverse:DominantNotImplemented', ...
        ['dominant-orientation reduction requires a frozen per-location orientation ' ...
         'computed at build time (SVD of the per-location source covariance over the ' ...
         'representative window); not yet implemented.']);
end
if isnumeric(source3d)
    X = source3d;
    if strcmp(mode,'vector'), scalar = X; else, scalar = reduce_matrix(X,mode); end
    return;
end
error('eegsl:Inverse:ReductionFormat','Expected numeric free-orientation estimates.');
end

function y = reduce_matrix(X,mode)
if mod(size(X,1),3) ~= 0
    error('eegsl:Inverse:ReductionComponents','Free-orientation rows must be divisible by 3.');
end
n = size(X,1)/3;
B = reshape(X,3,n,[]);
switch mode
    case 'norm'
        y = squeeze(sqrt(sum(abs(B).^2,1)));
    otherwise
        error('eegsl:Inverse:ReductionMode','Unsupported reduction mode: %s.',mode);
end
if isvector(y) && size(X,2) == 1, y = y(:); end
end
