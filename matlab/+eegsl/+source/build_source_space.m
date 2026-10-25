function [sourcemodel, info] = build_source_space(anatomy, elec, cfg)
%BUILD_SOURCE_SPACE Construct a regular world-coordinate source lattice.
if nargin < 3, cfg = struct(); end
base = eegsl.default_config();
if isfield(cfg,'source'), sourceCfg = merge_struct(base.source,cfg.source); else, sourceCfg = base.source; end
if strcmp(sourceCfg.mode,'cortical') && strcmp(sourceCfg.cortical_representation,'surface')
    [sourcemodel,info] = build_surface_source(anatomy,elec,sourceCfg);
    return;
end
if ~isstruct(anatomy) || ~isfield(anatomy,'mask')
    error('eegsl:Source:MissingMask','anatomy.mask is required.');
end
if ~islogical(anatomy.mask) || ndims(anatomy.mask) ~= 3
    error('eegsl:Source:MaskDimension','anatomy.mask must be a 3-D logical volume.');
end
if ~any(anatomy.mask(:))
    error('eegsl:Source:EmptyMask','anatomy.mask must contain at least one voxel.');
end
if ~isfield(anatomy,'transform') || ~isequal(size(anatomy.transform),[4 4])
    error('eegsl:Source:Transform','anatomy.transform must be a 4x4 affine.');
end
if ~isfield(anatomy,'transform_convention') || ...
        ~ismember(lower(char(anatomy.transform_convention)),{'fieldtrip','nifti'})
    error('eegsl:Source:TransformConvention', ...
        'anatomy.transform_convention must be fieldtrip or nifti.');
end
if ~isfield(anatomy,'unit') || isempty(anatomy.unit)
    error('eegsl:Source:MissingUnit','anatomy.unit is required.');
end
if ~isempty(sourceCfg.spacing_mm)
    if ~isscalar(sourceCfg.spacing_mm)
        error('eegsl:Source:AnisotropicSpacing','source.spacing_mm must be scalar.');
    end
    if ~(isnumeric(sourceCfg.spacing_mm) && isfinite(sourceCfg.spacing_mm) && sourceCfg.spacing_mm>0)
        error('eegsl:Source:Spacing','source.spacing_mm must be a positive scalar.');
    end
end
if sourceCfg.symmetry
    if ~isfield(anatomy,'coordsys') || isempty(anatomy.coordsys)
        error('eegsl:Source:MissingCoordsys','anatomy.coordsys is required when symmetry is enabled.');
    end
    lrSystems = {'ras','las','lps','rps','acpc','mni','tal','scanras','spm'};
    if ~ismember(lower(char(anatomy.coordsys)),lrSystems)
        error('eegsl:Source:CoordsysNotLR','The coordinate system must have left-right on the x axis.');
    end
end

mask = anatomy.mask;
unit = lower(char(anatomy.unit));
T1 = double(anatomy.transform);
if strcmpi(char(anatomy.transform_convention),'nifti')
    T1 = T1*[eye(3),-ones(3,1);0 0 0 1];
end
maskIndex = find(mask);
[mi,mj,mk] = ind2sub(size(mask),maskIndex);
maskVoxels = [mi mj mk];
W = voxel_to_world(T1,maskVoxels);
voxelVolume = abs(det(T1(1:3,1:3)));
heuristic = eegsl.source.electrode_density_heuristic(infer_channel_count(elec),sourceCfg);
unitScale = unit_to_mm(unit);
if isempty(sourceCfg.spacing_mm)
    spacing = (nnz(mask)*voxelVolume/heuristic.target_points)^(1/3);
    iterations = 0;
    finalCount = 0;
    for k = 1:10
        [~,~,insideNow] = make_lattice(W,mask,T1,spacing,sourceCfg,anatomy);
        finalCount = nnz(insideNow);
        iterations = k;
        if abs(finalCount-heuristic.target_points) <= 0.05*heuristic.target_points
            break;
        end
        if finalCount == 0, spacing = spacing*0.5;
        else, spacing = spacing*(finalCount/heuristic.target_points)^(1/3); end
    end
else
    spacing = double(sourceCfg.spacing_mm)/unitScale;
    iterations = 0;
    finalCount = NaN;
end
[pos,gridTransform,inside,ijk] = make_lattice(W,mask,T1,spacing,sourceCfg,anatomy);
if sourceCfg.symmetry && strcmp(sourceCfg.symmetry_mode,'enforce')
    inside = inside & mirror_inside(inside,[numel(unique_axis(pos(:,1))), ...
        numel(unique_axis(pos(:,2))),numel(unique_axis(pos(:,3)))]);
end
if sourceCfg.neighbor_continuity
    dim = [numel(unique_axis(pos(:,1))),numel(unique_axis(pos(:,2))),numel(unique_axis(pos(:,3)))];
    occ = reshape(inside,dim);
    for pass = 1:sourceCfg.neighbor_passes
        count = convn(double(occ),ones(3,3,3),'same')-double(occ);
        occ = occ & count >= sourceCfg.neighbor_min;
    end
    inside = occ(:);
end
dim = [numel(unique_axis(pos(:,1))),numel(unique_axis(pos(:,2))),numel(unique_axis(pos(:,3)))];
mirror = mirror_indices(dim);
unpaired = find(inside & ~inside(mirror));
[labels,tiers,provenance] = point_labels(inside,ijk,mask,anatomy);
if strcmp(sourceCfg.mode,'cortical')
    provenance(inside) = {'caller_supplied_cortical_mask'};
end

sourcemodel = struct('pos',pos,'inside',logical(inside(:)),'dim',dim, ...
    'transform',gridTransform,'unit',char(anatomy.unit), ...
    'coordsys',getf(anatomy,'coordsys',''),'label',{labels}, ...
    'source_tier',{tiers},'source_provenance',{provenance}, ...
    'orientation',orientation_for_mode(sourceCfg.mode));
sourcemodel.source_space_id = eegsl.common.content_hash(struct( ...
    'pos',pos,'inside',inside(:),'labels',{labels},'tiers',{tiers}, ...
    'provenance',{provenance},'mode',sourceCfg.mode, ...
    'symmetry_mode',sourceCfg.symmetry_mode,'unit',sourcemodel.unit, ...
    'coordsys',sourcemodel.coordsys));
if strcmp(sourceCfg.mode,'cortical')
    sourcemodel.cortical_mask_supplied = true;
end

midsagittal = struct('value',NaN,'method','not_used');
if sourceCfg.symmetry
    midsagittal.value = midsagittal_coordinate(sourceCfg.midsagittal_x,W);
    if ischar(sourceCfg.midsagittal_x) || isstring(sourceCfg.midsagittal_x)
        midsagittal.method = 'mask_centroid';
    else
        midsagittal.method = 'configured_world_x';
    end
end
info = eegsl.common.provenance('source_space',struct( ...
    'mode',sourceCfg.mode,'nchan',infer_channel_count(elec), ...
    'npoints',size(pos,1),'ninside',nnz(inside), ...
    'spacing',spacing,'spacing_mm',spacing*unitScale, ...
    'spacing_iterations',iterations,'final_count',finalCount, ...
    'target_points',heuristic.target_points,'symmetry',sourceCfg.symmetry, ...
    'symmetry_mode',sourceCfg.symmetry_mode,'midsagittal',midsagittal, ...
    'unpaired_points',unpaired,'neighbor_continuity',sourceCfg.neighbor_continuity, ...
    'orientation',sourcemodel.orientation,'source_space_id',sourcemodel.source_space_id));
if strcmp(sourceCfg.mode,'cortical'), info.cortical_mask_supplied = true; end
info.midsagittal = midsagittal;
info.unpaired_points = unpaired;
info.spacing_iterations = iterations;
info.final_count = nnz(inside);
end

function [pos,Tgrid,inside,ijk] = make_lattice(W,mask,T1,s,sourceCfg,anatomy)
if sourceCfg.symmetry
    x0 = midsagittal_coordinate(sourceCfg.midsagittal_x,W);
    halfw = s*ceil(max(abs(W(:,1)-x0))/s);
    xs = x0-halfw:s:x0+halfw;
else
    x0 = NaN;
    xs = s*floor(min(W(:,1))/s):s:s*ceil(max(W(:,1))/s);
end
ys = s*floor(min(W(:,2))/s):s:s*ceil(max(W(:,2))/s);
zs = s*floor(min(W(:,3))/s):s:s*ceil(max(W(:,3))/s);
[X,Y,Z] = ndgrid(xs,ys,zs);
pos = [X(:) Y(:) Z(:)];
Tgrid = [s 0 0 xs(1)-s;0 s 0 ys(1)-s;0 0 s zs(1)-s;0 0 0 1];
vox = T1\[pos';ones(1,size(pos,1))];
ijk = round(vox(1:3,:)');
dimMask = size(mask);
valid = all(ijk>=1,2) & all(ijk<=dimMask,2);
inside = false(size(pos,1),1);
validRows = find(valid);
if ~isempty(validRows)
    linear = sub2ind(dimMask,ijk(validRows,1),ijk(validRows,2),ijk(validRows,3));
    inside(validRows) = mask(linear);
end
if ~isempty(x0) && sourceCfg.symmetry && ~isfinite(x0)
    error('eegsl:Source:Midline','Unable to determine the midsagittal world x coordinate.');
end
if isfield(anatomy,'labels') && ~isempty(anatomy.labels) && ...
        ~isequal(size(anatomy.labels),size(mask))
    error('eegsl:Source:LabelDimension','anatomy.labels must match anatomy.mask.');
end
end

function W = voxel_to_world(T,vox)
world = T*[vox';ones(1,size(vox,1))];
W = world(1:3,:)';
end

function [labels,tiers,provenance] = point_labels(inside,ijk,mask,anatomy)
n = numel(inside);
labels = repmat({'outside'},n,1);
tiers = repmat({'outside'},n,1);
provenance = repmat({'outside'},n,1);
if ~any(inside), return; end
if ~isfield(anatomy,'labels') || isempty(anatomy.labels)
    labels(inside) = {'unknown'};
    tiers(inside) = {'unclassified'};
    provenance(inside) = {'mask'};
    return;
end
dim = size(mask);
sel = find(inside);
lin = sub2ind(dim,ijk(sel,1),ijk(sel,2),ijk(sel,3));
values = anatomy.labels(lin);
[mapped,tier,source] = map_labels(values,anatomy);
labels(sel) = mapped;
tiers(sel) = tier;
provenance(sel) = source;
end

function x0 = midsagittal_coordinate(value,W)
if ischar(value) || isstring(value)
    if ~strcmpi(char(value),'mask_centroid')
        error('eegsl:Source:Midline','midsagittal_x must be numeric or mask_centroid.');
    end
    x0 = mean(W(:,1));
else
    x0 = double(value);
end
end

function inside = mirror_inside(inside,dim)
inside = reshape(inside,dim);
inside = inside & flip(inside,1);
inside = inside(:);
end
function idx = mirror_indices(dim)
[i,j,k] = ndgrid(1:dim(1),1:dim(2),1:dim(3));
idx = sub2ind(dim,dim(1)+1-i,j,k);
idx = idx(:);
end
function a = unique_axis(x)
a = unique(x,'stable');
end
function n = infer_channel_count(elec)
if isempty(elec), n = 0;
elseif isstruct(elec) && isfield(elec,'chanpos'), n = size(elec.chanpos,1);
elseif isstruct(elec) && isfield(elec,'elecpos'), n = size(elec.elecpos,1);
elseif isnumeric(elec), n = size(elec,1);
else, error('eegsl:Source:ElectrodeFormat','Cannot infer electrode count.');
end
end
function orient = orientation_for_mode(mode)
if strcmpi(mode,'cortical'), orient='free'; else, orient='free'; end
end
function [names,tiers,provenance] = map_labels(values,anatomy)
names = repmat({'unknown'},numel(values),1);
tiers = repmat({'unclassified'},numel(values),1);
provenance = repmat({'label_volume'},numel(values),1);
if ~isfield(anatomy,'label_map') || isempty(anatomy.label_map), return; end
for k = 1:numel(anatomy.label_map)
    m = anatomy.label_map(k);
    hit = values == m.value;
    names(hit) = {char(m.name)};
    if isfield(m,'tier'), tiers(hit) = {char(m.tier)}; end
    if isfield(m,'provenance'), provenance(hit) = {char(m.provenance)}; end
end
end
function value = unit_to_mm(unit)
switch unit
    case 'mm', value=1;
    case 'cm', value=10;
    case 'm', value=1000;
    otherwise, error('eegsl:Source:Unit','anatomy.unit must be mm, cm, or m.');
end
end
function value = getf(s,name,default)
if isfield(s,name), value=s.(name); else, value=default; end
end
function [sourcemodel,info] = build_surface_source(anatomy,elec,sourceCfg)
if ~isstruct(anatomy) || ~isfield(anatomy,'surface') || ~isstruct(anatomy.surface)
    error('eegsl:Source:MissingSurface','anatomy.surface with pos, tri, and nrm is required.');
end
surface = anatomy.surface;
if ~isfield(surface,'nrm') || isempty(surface.nrm)
    error('eegsl:Source:MissingNormals','Surface-normal sources require anatomy.surface.nrm.');
end
if ~isfield(surface,'pos') || ~isfield(surface,'tri')
    error('eegsl:Source:SurfaceFormat','anatomy.surface.pos and tri are required.');
end
if ~isfield(anatomy,'unit') || isempty(anatomy.unit)
    error('eegsl:Source:MissingUnit','anatomy.unit is required.');
end
pos = double(surface.pos);
nrm = double(surface.nrm);
if size(pos,2) ~= 3 || ~isequal(size(nrm),size(pos)) || any(~isfinite(pos(:))) || any(~isfinite(nrm(:)))
    error('eegsl:Source:SurfaceFormat','Surface positions and normals must be finite N-by-3 arrays.');
end
norms = sqrt(sum(nrm.^2,2));
if any(norms <= eps), error('eegsl:Source:SurfaceNormals','Surface normals must be nonzero.'); end
nrm = nrm./norms;
n = size(pos,1);
labels = repmat({'cortex'},n,1);
tiers = repmat({'cortical'},n,1);
provenance = repmat({'surface'},n,1);
if isfield(surface,'label') && numel(surface.label)==n, labels=surface.label(:); end
sourcemodel = struct('pos',pos,'tri',surface.tri,'nrm',nrm, ...
    'inside',true(n,1),'unit',char(anatomy.unit), ...
    'coordsys',getf(anatomy,'coordsys',''),'label',{labels}, ...
    'source_tier',{tiers},'source_provenance',{provenance}, ...
    'orientation','surface-normal');
sourcemodel.source_space_id = eegsl.common.content_hash(struct( ...
    'pos',pos,'inside',sourcemodel.inside,'nrm',nrm, ...
    'labels',{labels},'tiers',{tiers},'mode',sourceCfg.mode, ...
    'unit',sourcemodel.unit,'coordsys',sourcemodel.coordsys));
info = eegsl.common.provenance('source_space',struct('mode',sourceCfg.mode, ...
    'representation','surface','nchan',infer_channel_count(elec), ...
    'npoints',n,'ninside',n,'orientation','surface-normal', ...
    'source_space_id',sourcemodel.source_space_id));
end
function out = merge_struct(base,override)
out=base;
for f=fieldnames(override)', out.(f{1})=override.(f{1}); end
end
