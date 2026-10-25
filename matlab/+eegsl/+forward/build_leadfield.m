function [leadfield, info] = build_leadfield(linked, elec, sourcemodel, cfg)
%BUILD_LEADFIELD Build a FieldTrip-compatible lead field.
%   FEM engines delegate to FieldTrip. The analytic path is adapter-only unless
%   the caller supplies a prepared lead field or a custom builder callback.
if nargin < 4, cfg = struct(); end
if isempty(sourcemodel)
    error('eegsl:Forward:MissingSourceModel','sourcemodel is required.');
end
base = eegsl.default_config();
if isfield(cfg,'forward'), fcfg = merge_struct(base.forward,cfg.forward); else, fcfg = base.forward; end
engine = lower(char(fcfg.engine));
orientation = resolve_orientation(sourcemodel,fcfg);

if ~isfield(sourcemodel,'pos')
    error('eegsl:Forward:SourceModel','sourcemodel.pos is required.');
end
if strcmp(orientation,'surface-normal') && ...
        (~isfield(sourcemodel,'nrm') || isempty(sourcemodel.nrm))
    error('eegsl:Forward:MissingNormals','surface-normal orientation requires sourcemodel.nrm.');
end
analyticCfg = base.forward.analytic;
if isfield(cfg,'forward') && isfield(cfg.forward,'analytic')
    analyticCfg = merge_struct(analyticCfg,cfg.forward.analytic);
end
if isfield(cfg,'analytic_leadfield') && ~isempty(cfg.analytic_leadfield)
    analyticCfg.leadfield = cfg.analytic_leadfield;
end
if isfield(cfg,'analytic_builder') && isa(cfg.analytic_builder,'function_handle')
    analyticCfg.builder = cfg.analytic_builder;
end

t0 = tic;
switch engine
    case {'simbio','duneuro'}
        require_fieldtrip(fcfg);
        if exist('ft_prepare_leadfield','file') ~= 2
            error('eegsl:Forward:MissingFieldTrip','ft_prepare_leadfield is required.');
        end
        ftcfg = get_field(cfg,'fieldtrip',struct());
        ftcfg.grid = sourcemodel;
        ftcfg.elec = elec;
        ftcfg.vol = linked;
        ftcfg.reducerank = get_field(ftcfg,'reducerank','no');
        ftcfg.fixedori = 'no';
        leadfield = ft_prepare_leadfield(ftcfg);
    case 'analytic'
        if ~isempty(analyticCfg.leadfield)
            leadfield = analyticCfg.leadfield;
        elseif isa(analyticCfg.builder,'function_handle')
            leadfield = analyticCfg.builder(linked,elec,sourcemodel,cfg);
        else
            error('eegsl:Forward:AnalyticAdapter', ...
                'Analytic leadfield requires cfg.forward.analytic.leadfield or builder.');
        end
    otherwise
        error('eegsl:Forward:Engine','Unsupported engine: %s.',engine);
end
if strcmp(orientation,'surface-normal')
    [leadfield,normalApplied] = project_normals(leadfield,sourcemodel, ...
        strcmp(engine,'analytic'),analyticCfg.prenormal);
else
    normalApplied = false;
end
elapsed = toc(t0);
leadfield.orientation = orientation;
if strcmp(orientation,'surface-normal'), leadfield.normals_applied = normalApplied; end
leadfield.source_space_id = get_source_id(sourcemodel);
keys = cache_keys(fcfg);
if isfield(keys,'leadfield_key')
    leadfield.leadfield_id = keys.leadfield_key;
else
    leadfield.leadfield_id = eegsl.common.cache_key('leadfield', ...
        leadfield.source_space_id,orientation, ...
        eegsl.common.content_hash(leadfield.leadfield));
end
info = eegsl.common.provenance('leadfield',struct( ...
    'engine',engine,'elapsed_seconds',elapsed,'orientation',orientation, ...
    'cache_keys',keys, ...
    'source_space_id',leadfield.source_space_id, ...
    'leadfield_id',leadfield.leadfield_id));
end

function orientation = resolve_orientation(sourcemodel,fcfg)
if isfield(fcfg,'orientation') && ~strcmpi(char(fcfg.orientation),'auto')
    orientation = lower(char(fcfg.orientation));
elseif isfield(sourcemodel,'orientation')
    orientation = lower(char(sourcemodel.orientation));
elseif isfield(sourcemodel,'tri')
    orientation = 'surface-normal';
else
    orientation = 'free';
end
if ~ismember(orientation,{'free','surface-normal','fixed'})
    error('eegsl:Forward:Orientation','Unsupported orientation: %s.',orientation);
end
if strcmp(orientation,'fixed'), orientation = 'surface-normal'; end
end
function [lf,applied] = project_normals(lf,sourcemodel,isAnalytic,prenormal)
nloc = size(sourcemodel.pos,1);
inside = true(nloc,1);
if isfield(sourcemodel,'inside') && ~isempty(sourcemodel.inside)
    inside = logical(sourcemodel.inside(:));
    if numel(inside) ~= nloc
        error('eegsl:Forward:InsideShape','sourcemodel.inside must match sourcemodel.pos.');
    end
end
nrm = double(sourcemodel.nrm);
if ~isequal(size(nrm),[nloc 3])
    error('eegsl:Forward:MissingNormals','sourcemodel.nrm must be N-by-3.');
end
normalLength = sqrt(sum(nrm.^2,2));
if any(normalLength(inside)<=eps)
    error('eegsl:Forward:MissingNormals','Inside source normals must be nonzero.');
end
nrm(inside,:) = nrm(inside,:)./normalLength(inside);
if isstruct(lf) && isfield(lf,'leadfield'), value = lf.leadfield; else, value = lf; end
if iscell(value)
    if numel(value) ~= nloc
        error('eegsl:Forward:AmbiguousBlocks','Lead-field blocks do not match source locations.');
    end
    blocks = value;
    for i = find(inside(:))'
        H = double(blocks{i});
        if isempty(H), error('eegsl:Forward:AmbiguousBlocks','An inside lead-field block is empty.'); end
        if size(H,2) == 3
            blocks{i} = H*nrm(i,:)';
        elseif size(H,2) == 1 && isAnalytic && prenormal
            blocks{i} = H;
        else
            error('eegsl:Forward:AmbiguousBlocks', ...
                'Expected three free-orientation columns, or analytic pre-normalized blocks.');
        end
    end
    if isstruct(lf), lf.leadfield = blocks; else, lf = struct('leadfield',{blocks}); end
elseif isnumeric(value) && ismatrix(value)
    if size(value,2) == 3*nloc
        blocks = cell(1,nloc);
        for i = 1:nloc
            cols = 3*i-2:3*i;
            if inside(i), blocks{i} = value(:,cols)*nrm(i,:)'; else, blocks{i} = []; end
        end
        if all(inside), projected = cat(2,blocks{:}); else, projected = blocks; end
    elseif size(value,2) == nloc && isAnalytic && prenormal
        blocks = arrayfun(@(i)value(:,i),1:nloc,'UniformOutput',false);
        blocks(~inside) = {[]};
        if all(inside), projected = value; else, projected = blocks; end
    else
        error('eegsl:Forward:AmbiguousBlocks', ...
            'Expected three free-orientation columns per source location.');
    end
    if isstruct(lf), lf.leadfield = projected; else, lf = struct('leadfield',projected); end
else
    error('eegsl:Forward:AmbiguousBlocks','Unsupported lead-field block representation.');
end
applied = true;
end
function id = get_source_id(s)
if isfield(s,'source_space_id')
    id = s.source_space_id;
else
    inside = [];
    if isfield(s,'inside'), inside = s.inside; end
    id = eegsl.common.content_hash(struct('pos',s.pos,'inside',inside));
end
end
function require_fieldtrip(fcfg)
if isfield(fcfg,'require_fieldtrip') && ~fcfg.require_fieldtrip, return; end
if exist('ft_prepare_leadfield','file') ~= 2
    error('eegsl:Forward:MissingFieldTrip', ...
        'FieldTrip is required for the FEM lead-field path.');
end
end
function value = get_field(s,name,default)
if isfield(s,name), value = s.(name); else, value = default; end
end
function keys = cache_keys(fcfg)
keys = struct();
if isfield(fcfg,'cache_keys') && isstruct(fcfg.cache_keys) && ~isempty(fcfg.cache_keys)
    keys = fcfg.cache_keys;
end
end
function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    out.(f{1}) = override.(f{1});
end
end
