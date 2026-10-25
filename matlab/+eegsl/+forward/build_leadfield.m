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
        if strcmp(orientation,'free')
            ftcfg.fixedori = 'no';
        else
            ftcfg.fixedori = 'yes';
        end
        leadfield = ft_prepare_leadfield(ftcfg);
    case 'analytic'
        if isfield(cfg,'analytic_leadfield') && ~isempty(cfg.analytic_leadfield)
            leadfield = cfg.analytic_leadfield;
        elseif isfield(cfg,'analytic_builder') && isa(cfg.analytic_builder,'function_handle')
            leadfield = cfg.analytic_builder(linked,elec,sourcemodel,cfg);
        else
            error('eegsl:Forward:AnalyticAdapter', ...
                'Analytic leadfield requires cfg.analytic_leadfield or cfg.analytic_builder.');
        end
    otherwise
        error('eegsl:Forward:Engine','Unsupported engine: %s.',engine);
end
elapsed = toc(t0);
leadfield.orientation = orientation;
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
