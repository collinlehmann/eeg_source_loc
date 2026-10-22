function info = validate_petra_config(cfg)
%VALIDATE_PETRA_CONFIG Validate explicit PETRA adapter configuration.
if nargin < 1 || isempty(cfg), cfg = struct(); end
info = struct('enabled',get_or(cfg,'enabled',false), ...
    'allow_fallback',get_or(cfg,'allow_fallback',true), ...
    'registration_backend',get_or(cfg,'registration_backend','adapter'), ...
    'segmentation_backend',get_or(cfg,'segmentation_backend','adapter'));
if info.enabled
    if ~isfield(cfg,'registration_callback') || ~isa(cfg.registration_callback,'function_handle')
        error('eegsl:PETRA:RegistrationCallback','Enabled PETRA requires registration_callback.');
    end
    if ~isfield(cfg,'segmentation_callback') || ~isa(cfg.segmentation_callback,'function_handle')
        error('eegsl:PETRA:SegmentationCallback','Enabled PETRA requires segmentation_callback.');
    end
end
end
function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
