function info = forward_cache_keys(mesh, conductivity, headmodel, elec, sourcemodel, cfg)
%FORWARD_CACHE_KEYS Return the three-level forward cache decomposition.
if nargin < 6, cfg = struct(); end
engine = get_engine(cfg);
stiffness = eegsl.common.cache_key('stiffness',mesh,conductivity,engine);
transfer = eegsl.common.cache_key('transfer',stiffness,elec);
orientation = get_orientation(sourcemodel,cfg);
leadfield = eegsl.common.cache_key('leadfield',transfer,sourcemodel,orientation);
info = struct('engine',engine,'stiffness_key',stiffness, ...
    'transfer_key',transfer,'leadfield_key',leadfield, ...
    'orientation',orientation,'headmodel_id',eegsl.common.content_hash(headmodel));
end

function e = get_engine(cfg)
if isfield(cfg,'forward') && isfield(cfg.forward,'engine'), e = lower(char(cfg.forward.engine)); else, e = 'simbio'; end
end
function o = get_orientation(s,cfg)
if isfield(cfg,'forward') && isfield(cfg.forward,'orientation') && ~strcmpi(char(cfg.forward.orientation),'auto')
    o = lower(char(cfg.forward.orientation));
elseif isfield(s,'orientation'), o = lower(char(s.orientation)); else, o = 'free'; end
end
