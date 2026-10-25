function [G, info] = geometry_term(leadfield, projector)
%GEOMETRY_TERM Accumulate sum_i H_i*H_i' for uniform-null covariance.
%   G is sensor-by-sensor. Lead fields may be FieldTrip cell arrays or a
%   numeric sensor-by-orientation matrix. The optional projector is applied
%   to every source block before accumulation.
if nargin < 2 || isempty(projector), projector = []; end
[blocks,blockInfo] = extract_blocks(leadfield);
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
    'inside_index',blockInfo.inside_index,'empty_indices',blockInfo.empty_indices, ...
    'geometry_id',eegsl.common.content_hash(G));
end

function [blocks,blockInfo] = extract_blocks(lf)
if isstruct(lf) && isfield(lf,'leadfield')
    value = lf.leadfield;
else
    value = lf;
end
if iscell(value)
    allBlocks = value;
elseif isnumeric(value) && ismatrix(value)
    orientation = '';
    if isstruct(lf) && isfield(lf,'orientation'), orientation = lower(char(lf.orientation)); end
    switch orientation
        case 'free'
            if mod(size(value,2),3) ~= 0
                error('eegsl:Noise:LeadfieldColumns','Free-orientation columns must be divisible by three.');
            end
            allBlocks = arrayfun(@(k)value(:,3*k-2:3*k), ...
                1:size(value,2)/3,'UniformOutput',false);
        case {'scalar','fixed','surface-normal'}
            allBlocks = arrayfun(@(k)value(:,k),1:size(value,2),'UniformOutput',false);
        otherwise
            error('eegsl:Noise:AmbiguousOrientation', ...
                'Numeric leadfields require an explicit orientation field.');
    end
else
    error('eegsl:Noise:LeadfieldFormat','Unsupported leadfield format.');
end
inside = [];
if isstruct(lf) && isfield(lf,'inside') && ~isempty(lf.inside)
    if numel(lf.inside) ~= numel(allBlocks)
        error('eegsl:Noise:InsideShape','Leadfield inside vector does not match source locations.');
    end
    inside = logical(lf.inside(:));
end
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
blockInfo = struct('inside_index',selected,'empty_indices',emptyIndices);
end
