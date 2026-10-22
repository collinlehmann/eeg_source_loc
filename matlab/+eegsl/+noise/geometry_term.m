function [G, info] = geometry_term(leadfield, projector)
%GEOMETRY_TERM Accumulate sum_i H_i*H_i' for uniform-null covariance.
%   G is sensor-by-sensor. Lead fields may be FieldTrip cell arrays or a
%   numeric sensor-by-orientation matrix. The optional projector is applied
%   to every source block before accumulation.
if nargin < 2 || isempty(projector), projector = []; end
blocks = extract_blocks(leadfield);
if isempty(blocks), error('eegsl:Noise:LeadfieldFormat','No lead-field blocks found.'); end
first = blocks{1};
if isempty(projector), projector = eye(size(first,1)); end
G = zeros(size(projector,1));
for k = 1:numel(blocks)
    H = double(blocks{k});
    if size(H,1) ~= size(projector,2)
        error('eegsl:Noise:LeadfieldChannels','Lead-field and projector channel counts differ.');
    end
    H = projector*H;
    G = G + H*H';
end
G = (G+G')/2;
info = struct('n_channels',size(G,1),'n_sources',numel(blocks), ...
    'orientation_columns',cellfun(@(x)size(x,2),blocks), ...
    'geometry_id',eegsl.common.content_hash(G));
end

function blocks = extract_blocks(lf)
if isstruct(lf) && isfield(lf,'leadfield')
    value = lf.leadfield;
else
    value = lf;
end
if iscell(value)
    blocks = value;
elseif isnumeric(value) && ismatrix(value)
    % Numeric matrices are interpreted as concatenated 3-orientation blocks
    % when possible, otherwise as fixed-orientation one-column blocks.
    if size(value,2) >= 3 && mod(size(value,2),3) == 0
        n = size(value,2)/3; blocks = cell(1,n);
        for k = 1:n, blocks{k} = value(:,3*k-2:3*k); end
    else
        blocks = cell(1,size(value,2));
        for k = 1:size(value,2), blocks{k} = value(:,k); end
    end
else
    blocks = {};
end
end
