function [headmodel, info] = build_headmodel(mesh, conductivity, cfg)
%BUILD_HEADMODEL Build a FieldTrip-compatible head model through an adapter.
%   No FEM assembly is implemented here. The SimBio/DUNEuro adapters delegate
%   to FieldTrip when available; analytic is an explicit fallback seam.
if nargin < 3, cfg = struct(); end
base = eegsl.default_config();
if isfield(cfg,'forward'), fcfg = merge_struct(base.forward,cfg.forward); else, fcfg = base.forward; end
engine = lower(char(fcfg.engine));

validate_mesh(mesh);
t0 = tic;
switch engine
    case 'simbio'
        require_fieldtrip(fcfg, 'simbio');
        ftcfg = get_field(cfg,'fieldtrip',struct());
        ftcfg.method = 'simbio';
        ftcfg.conductivity = conductivity;
        headmodel = call_prepare_headmodel(mesh,ftcfg);
    case 'duneuro'
        require_fieldtrip(fcfg, 'duneuro');
        ftcfg = get_field(cfg,'fieldtrip',struct());
        ftcfg.method = 'duneuro';
        ftcfg.conductivity = conductivity;
        headmodel = call_prepare_headmodel(mesh,ftcfg);
    case 'analytic'
        headmodel = build_analytic_adapter(mesh,conductivity,cfg);
    otherwise
        error('eegsl:Forward:Engine','Unsupported engine: %s.',engine);
end
elapsed = toc(t0);
info = eegsl.common.provenance('headmodel',struct( ...
    'engine',engine,'elapsed_seconds',elapsed, ...
    'conductivity',conductivity,'mesh_id',eegsl.common.content_hash(mesh), ...
    'headmodel_id',eegsl.common.content_hash(headmodel)));
end

function headmodel = call_prepare_headmodel(mesh,cfg)
if exist('ft_prepare_headmodel','file') ~= 2
    error('eegsl:Forward:MissingFieldTrip','ft_prepare_headmodel is required for this engine.');
end
headmodel = ft_prepare_headmodel(cfg,mesh);
end

function headmodel = build_analytic_adapter(mesh,conductivity,cfg)
% Explicit adapter-only representation; a numerical analytic solver is not
% silently substituted for FEM. A caller may provide a prepared headmodel.
if isfield(cfg,'analytic_headmodel') && ~isempty(cfg.analytic_headmodel)
    headmodel = cfg.analytic_headmodel;
    return;
end
headmodel = struct('type','analytic-adapter','mesh',mesh, ...
    'conductivity',conductivity,'engine','analytic');
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
function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    out.(f{1}) = override.(f{1});
end
end
