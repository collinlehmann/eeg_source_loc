function info = validate_petra_config(cfg)
%VALIDATE_PETRA_CONFIG Resolve canonical or legacy PETRA configuration.
if nargin < 1 || isempty(cfg), cfg = struct(); end
base=eegsl.default_config().petra;
if isstruct(cfg) && isfield(cfg,'petra') && isstruct(cfg.petra)
    info=merge_struct(base,cfg.petra);
elseif isstruct(cfg) && any(isfield(cfg, ...
        {'enabled','registration_callback','segmentation_callback'}))
    warning('eegsl:PETRA:LegacyConfig','Pass PETRA options in cfg.petra.');
    info=merge_struct(base,cfg);
else
    info=base;
end
end
function out=merge_struct(base,override)
out=base;
for f=fieldnames(override)'
    name=f{1};
    if isstruct(override.(name))&&isfield(out,name)&&isstruct(out.(name))
        out.(name)=merge_struct(out.(name),override.(name));
    else
        out.(name)=override.(name);
    end
end
end
