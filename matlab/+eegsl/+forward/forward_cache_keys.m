function keys = forward_cache_keys(mesh, conductivity, elec, sourcemodel, cfg)
%FORWARD_CACHE_KEYS Derive stable keys from forward inputs, not computed outputs.
if nargin < 5 || isempty(cfg), cfg = eegsl.default_config(); end
cfg = merge_config(eegsl.default_config(),cfg);
elecGeom = struct('elecpos',getf(elec,'elecpos',[]), ...
    'chanpos',getf(elec,'chanpos',[]),'label',{getf(elec,'label',{})}, ...
    'unit',getf(elec,'unit',''),'coordsys',getf(elec,'coordsys',''));
stiffness = eegsl.common.cache_key('stiffness', ...
    eegsl.common.stage_fingerprint('stiffness',cfg), ...
    eegsl.common.content_hash(mesh),conductivity);
transfer = eegsl.common.cache_key('transfer',stiffness, ...
    eegsl.common.stage_fingerprint('transfer',cfg), ...
    eegsl.common.content_hash(elecGeom));
sourceId = source_space_id(sourcemodel);
orientation = resolve_orientation(sourcemodel,cfg.forward);
leadfield = eegsl.common.cache_key('leadfield',transfer, ...
    eegsl.common.stage_fingerprint('leadfield',cfg),sourceId,orientation);
keys = struct('engine',cfg.forward.engine,'stiffness_key',stiffness, ...
    'transfer_key',transfer,'leadfield_key',leadfield,'orientation',orientation);
end

function id = source_space_id(s)
if isfield(s,'source_space_id')
    id = s.source_space_id;
else
    inside = [];
    if isfield(s,'inside'), inside = s.inside; end
    id = eegsl.common.content_hash(struct('pos',s.pos,'inside',inside));
end
end

function orientation = resolve_orientation(s,fcfg)
if ~strcmpi(char(fcfg.orientation),'auto')
    orientation = lower(char(fcfg.orientation));
elseif isfield(s,'orientation')
    orientation = lower(char(s.orientation));
elseif isfield(s,'tri')
    orientation = 'surface-normal';
else
    orientation = 'free';
end
if strcmp(orientation,'fixed'), orientation = 'surface-normal'; end
end

function value = getf(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end

function out = merge_config(base,override)
out = base;
for f = fieldnames(override)'
    name = f{1};
    if isstruct(override.(name)) && isfield(out,name) && isstruct(out.(name))
        out.(name) = merge_config(out.(name),override.(name));
    else
        out.(name) = override.(name);
    end
end
end
