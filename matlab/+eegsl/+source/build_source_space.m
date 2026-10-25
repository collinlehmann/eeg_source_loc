function [sourcemodel, info] = build_source_space(anatomy, elec, cfg)
%BUILD_SOURCE_SPACE Build a regular volumetric FieldTrip-compatible source grid.
%   anatomy.mask must be a 3-D logical volume. Optional anatomy fields:
%   transform (4x4 voxel-to-world affine), unit, labels (numeric volume),
%   label_map (struct array with value/name/tier/provenance).
%
%   The default is a whole-brain volumetric grid. The function is dependency-
%   free and does not call FieldTrip; the resulting struct follows its
%   sourcemodel conventions and can be adapted with ft_convert_units later.

if nargin < 3, cfg = struct(); end
if ~isstruct(anatomy) || ~isfield(anatomy,'mask')
    error('eegsl:Source:MissingMask','anatomy.mask is required.');
end
mask = logical(anatomy.mask);
if ndims(mask) ~= 3
    error('eegsl:Source:MaskDimension','anatomy.mask must be a 3-D volume.');
end

base = eegsl.default_config();
if isfield(cfg,'source'), sourceCfg = merge_struct(base.source,cfg.source); else, sourceCfg = base.source; end
nchan = infer_channel_count(elec);
heuristic = eegsl.source.electrode_density_heuristic(nchan, sourceCfg);

voxelSize = get_voxel_size(anatomy);
 if isempty(sourceCfg.spacing_mm)
     s = max(1,ceil((nnz(mask)/max(1,heuristic.target_points))^(1/3)));
     stride = repmat(s,1,3);
     spacing = stride .* voxelSize;
 else
     spacing = sourceCfg.spacing_mm;
     if isscalar(spacing), spacing = repmat(spacing,1,3); end
     stride = max(1,round(spacing ./ voxelSize));
 end

idx = false(size(mask));
idx(1:stride(1):end,1:stride(2):end,1:stride(3):end) = true;
idx = idx & mask;
if sourceCfg.neighbor_continuity
    idx = apply_neighbor_continuity(idx);
end
if sourceCfg.symmetry
    idx = enforce_grid_symmetry(idx) & mask;
end

[iv,jv,kv] = ind2sub(size(idx),find(idx));
vox = [iv jv kv];
transform = get_transform(anatomy);
pos = apply_affine(transform,vox);

labels = repmat({'unknown'},size(iv));
tiers = repmat({'unclassified'},size(iv));
provenance = repmat({'mask'},size(iv));
if isfield(anatomy,'labels') && ~isempty(anatomy.labels)
    if ~isequal(size(anatomy.labels),size(mask))
        error('eegsl:Source:LabelDimension','anatomy.labels must match anatomy.mask.');
    end
    values = anatomy.labels(idx);
    [labels,tiers,provenance] = map_labels(values,anatomy);
end

sourcemodel = struct();
sourcemodel.pos = pos;
sourcemodel.inside = true(size(pos,1),1);
sourcemodel.outside = false(size(pos,1),1);
sourcemodel.dim = size(mask);
sourcemodel.transform = transform;
sourcemodel.unit = get_unit(anatomy);
sourcemodel.label = labels;
sourcemodel.source_tier = tiers;
sourcemodel.source_provenance = provenance;
sourcemodel.orientation = orientation_for_mode(sourceCfg.mode);
sourcemodel.source_space_id = eegsl.common.content_hash(struct( ...
    'mask',mask,'transform',transform,'pos',pos,'labels',{labels}, ...
    'mode',sourceCfg.mode));

info = eegsl.common.provenance('source_space',struct( ...
    'mode',sourceCfg.mode,'nchan',nchan,'npoints',size(pos,1), ...
    'voxel_size',voxelSize,'spacing_mm',spacing,'stride_voxels',stride, ...
    'target_points',heuristic.target_points,'symmetry',sourceCfg.symmetry, ...
    'neighbor_continuity',sourceCfg.neighbor_continuity, ...
    'orientation',sourcemodel.orientation,'source_space_id',sourcemodel.source_space_id));
end

function n = infer_channel_count(elec)
if isempty(elec), n = 0; return; end
if isstruct(elec) && isfield(elec,'chanpos'), n = size(elec.chanpos,1); return; end
if isstruct(elec) && isfield(elec,'elecpos'), n = size(elec.elecpos,1); return; end
if isnumeric(elec), n = size(elec,1); return; end
error('eegsl:Source:ElectrodeFormat','Cannot infer electrode count.');
end

function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    name = f{1};
    out.(name) = override.(name);
end
end

function t = get_transform(anatomy)
if isfield(anatomy,'transform') && ~isempty(anatomy.transform)
    t = anatomy.transform;
else
    t = eye(4);
end
if ~isequal(size(t),[4 4]), error('eegsl:Source:Transform','transform must be 4x4.'); end
end

function v = get_voxel_size(anatomy)
t = get_transform(anatomy);
v = sqrt(sum(t(1:3,1:3).^2,1));
v(v == 0) = 1;
end

function u = get_unit(anatomy)
if isfield(anatomy,'unit') && ~isempty(anatomy.unit), u = char(anatomy.unit); else, u = 'mm'; end
end

function p = apply_affine(t,vox)
p = (t * [vox - 1,ones(size(vox,1),1)]')';
p = p(:,1:3);
end

function out = apply_neighbor_continuity(in)
out = false(size(in));
for x = 2:size(in,1)-1
    for y = 2:size(in,2)-1
        for z = 2:size(in,3)-1
            block = in(x-1:x+1,y-1:y+1,z-1:z+1);
            block(2,2,2) = false;
            if in(x,y,z) && nnz(block) >= 8, out(x,y,z) = true; end
        end
    end
end
end

function out = enforce_grid_symmetry(in)
% Left-right symmetry: reflect across the mid-sagittal plane (assumed to be
% the centre of voxel dimension 1; dimension 1 is assumed to be L-R).
% Union with the mirror image so a strided grid is never emptied. If the mask
% itself is not symmetric, the caller's mask intersection can still leave
% asymmetry.
out = in | flip(in,1);
end

function orient = orientation_for_mode(mode)
if strcmpi(mode,'cortical'), orient = 'surface-normal'; else, orient = 'free'; end
end

function [names,tiers,provenance] = map_labels(values,anatomy)
names = repmat({'unknown'},size(values)); tiers = repmat({'unclassified'},size(values)); provenance = repmat({'label_volume'},size(values));
if ~isfield(anatomy,'label_map') || isempty(anatomy.label_map), return; end
for k = 1:numel(anatomy.label_map)
    m = anatomy.label_map(k);
    hit = values == m.value;
    names(hit) = {char(m.name)};
    if isfield(m,'tier'), tiers(hit) = {char(m.tier)}; end
    if isfield(m,'provenance'), provenance(hit) = {char(m.provenance)}; end
end
end