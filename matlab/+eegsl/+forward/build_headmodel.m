function [headmodel, info] = build_headmodel(mesh, conductivity, cfg)
%BUILD_HEADMODEL Build a FieldTrip-compatible head model through an adapter.
%   No FEM assembly is implemented here. The SimBio/DUNEuro adapters delegate
%   to FieldTrip when available; analytic is an explicit fallback seam.
if nargin < 3, cfg = struct(); end
reject_legacy_fieldtrip(cfg);
base = eegsl.default_config();
if isfield(cfg,'forward'), fcfg = merge_struct(base.forward,cfg.forward); else, fcfg = base.forward; end
engine = lower(char(fcfg.engine));

validate_mesh(mesh);
conductivityInfo = struct('tissuelabel',{{}},'values',[]);
t0 = tic;
switch engine
    case 'simbio'
        [conductivity,conductivityInfo] = eegsl.forward.resolve_conductivity(mesh,conductivity);
        require_fieldtrip(fcfg, 'simbio');
        ftcfg = get_field(fcfg.fieldtrip,'headmodel',struct());
        ftcfg.method = 'simbio';
        ftcfg.conductivity = conductivity;
        headmodel = call_prepare_headmodel(mesh,ftcfg);
    case 'duneuro'
        [conductivity,conductivityInfo] = eegsl.forward.resolve_conductivity(mesh,conductivity);
        require_fieldtrip(fcfg, 'duneuro');
        ftcfg = get_field(fcfg.fieldtrip,'headmodel',struct());
        ftcfg.method = 'duneuro';
        ftcfg.conductivity = conductivity;
        headmodel = call_prepare_headmodel(mesh,ftcfg);
    case 'analytic'
        analyticCfg = merge_struct(base.forward.analytic, ...
            get_field(fcfg,'analytic',struct()));
        headmodel = build_analytic_adapter(mesh,conductivity,cfg,analyticCfg);
    otherwise
        error('eegsl:Forward:Engine','Unsupported engine: %s.',engine);
end
elapsed = toc(t0);
info = eegsl.common.provenance('headmodel',struct( ...
    'engine',engine,'elapsed_seconds',elapsed, ...
    'conductivity',conductivityInfo,'conductivity_values',conductivity, ...
    'mesh_id',eegsl.common.content_hash(mesh), ...
    'cache_keys',cache_keys(fcfg),'conductivity_info',conductivityInfo));
end

function headmodel = call_prepare_headmodel(mesh,cfg)
if exist('ft_prepare_headmodel','file') ~= 2
    error('eegsl:Forward:MissingFieldTrip','ft_prepare_headmodel is required for this engine.');
end
headmodel = ft_prepare_headmodel(cfg,mesh);
end

function headmodel = build_analytic_adapter(mesh,conductivity,cfg,analyticCfg)
% Explicit adapter-only representation; a numerical analytic solver is not
% silently substituted for FEM. A caller may provide a prepared headmodel.
hasLegacy = isfield(cfg,'analytic_headmodel') && ~isempty(cfg.analytic_headmodel);
if hasLegacy
    warning('eegsl:Forward:LegacyAnalyticConfig', ...
        'Use cfg.forward.analytic.headmodel instead of cfg.analytic_headmodel.');
end
if ~isempty(analyticCfg.headmodel)
    headmodel = analyticCfg.headmodel;
    return;
end
if hasLegacy
    headmodel = cfg.analytic_headmodel;
    return;
end
headmodel = struct('type','analytic-adapter','mesh',mesh, ...
    'conductivity',conductivity,'engine','analytic');
if isfield(mesh,'unit'), headmodel.unit = mesh.unit; end
if isfield(mesh,'coordsys'), headmodel.coordsys = mesh.coordsys; end
end

function validate_mesh(mesh)
if ~isstruct(mesh)
    error('eegsl:Forward:Mesh','mesh must be a struct.');
end
end

function require_fieldtrip(fcfg,engine)
if isfield(fcfg,'require_fieldtrip') && ~fcfg.require_fieldtrip, return; end
if exist('ft_prepare_headmodel','file') ~= 2
    error('eegsl:Forward:MissingFieldTrip', ...
        'FieldTrip is required for the %s engine; add it to the MATLAB path.',engine);
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
function reject_legacy_fieldtrip(cfg)
if isstruct(cfg) && isfield(cfg,'fieldtrip')
    error('eegsl:Forward:LegacyFieldTripConfig', ...
        'Move cfg.fieldtrip options to cfg.forward.fieldtrip.headmodel, .vol_sens, or .leadfield.');
end
end
