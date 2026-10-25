function [linked, elecProjected, info] = link_sensors(headmodel, elec, cfg)
%LINK_SENSORS Build/retrieve the FEM sensor transfer stage.
%   For SimBio/DUNEuro, FieldTrip performs the transfer-matrix construction.
%   The expensive operation is timed and recorded. No per-source FEM solves
%   are performed here.
if nargin < 3, cfg = struct(); end
if isempty(headmodel) || isempty(elec)
    error('eegsl:Forward:MissingInput','headmodel and elec are required.');
end
base = eegsl.default_config();
if isfield(cfg,'forward'), fcfg = merge_struct(base.forward,cfg.forward); else, fcfg = base.forward; end
engine = lower(char(fcfg.engine));
eegsl.common.assert_coordinates(headmodel,elec);

if isfield(elec,'unit') && ~isempty(elec.unit) && isfield(headmodel,'unit') && ~isempty(headmodel.unit)
    if ~strcmpi(char(elec.unit),char(headmodel.unit))
        error('eegsl:Forward:UnitMismatch','Electrode and head-model units differ.');
    end
end

t0 = tic;
switch engine
    case {'simbio','duneuro'}
        require_fieldtrip(fcfg,engine);
        if exist('ft_prepare_vol_sens','file') ~= 2
            error('eegsl:Forward:MissingFieldTrip','ft_prepare_vol_sens is required.');
        end
        ftcfg = get_field(cfg,'fieldtrip',struct());
        [linked,elecProjected] = ft_prepare_vol_sens(headmodel,elec,ftcfg);
    case 'analytic'
        linked = struct('headmodel',headmodel,'elec',elec,'type','analytic-adapter');
        elecProjected = elec;
    otherwise
        error('eegsl:Forward:Engine','Unsupported engine: %s.',engine);
end
elapsed = toc(t0);
info = eegsl.common.provenance('sensor_link',struct( ...
    'engine',engine,'elapsed_seconds',elapsed, ...
    'cache_keys',cache_keys(fcfg), ...
    'electrode_id',eegsl.common.content_hash(elec)));
end

function require_fieldtrip(fcfg,engine)
if isfield(fcfg,'require_fieldtrip') && ~fcfg.require_fieldtrip, return; end
if exist('ft_prepare_vol_sens','file') ~= 2
    error('eegsl:Forward:MissingFieldTrip', ...
        'FieldTrip is required for the %s sensor-linking path.',engine);
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
