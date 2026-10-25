function cfg = validate_config(cfg)
%VALIDATE_CONFIG Validate preprocessing mode guards and adapter contracts.
if nargin < 1 || isempty(cfg), cfg = struct(); end
cfg = merge_struct(defaults(),cfg);
cfg.mode = lower(char(cfg.mode));
if ~ismember(cfg.mode,{'interactive-offline','automated-offline','realtime'})
    error('eegsl:Preprocess:Mode','Unsupported preprocessing mode: %s.',cfg.mode);
end
cfg.filter.enabled = require_logical(cfg.filter.enabled,'filter.enabled');
if ~isempty(cfg.filter_callback) && ~cfg.filter.enabled
    error('eegsl:Preprocess:FilterFlagMismatch', ...
        'filter_callback cannot be used unless filter.enabled is true.');
end
if cfg.filter.enabled && isempty(cfg.filter_callback)
    error('eegsl:Preprocess:FilterAdapter','Filtering requires an explicit filter_callback.');
end
if cfg.filter.enabled
    if isempty(cfg.filter.type) || isempty(cfg.filter.order) || ...
            isempty(cfg.filter.band) || ~islogical(cfg.filter.causal) || ...
            ~isscalar(cfg.filter.causal)
        error('eegsl:Preprocess:FilterProvenance', ...
            'Enabled filtering requires type, order, band, and scalar logical causal provenance.');
    end
end
if strcmp(cfg.mode,'realtime') && cfg.filter.enabled && ~cfg.filter.causal
    error('eegsl:Preprocess:NoncausalRealtime','Real-time filtering must be causal.');
end
if strcmp(cfg.mode,'realtime') && cfg.artifact.enabled && ...
        strcmpi(cfg.artifact.method,'ica') && ~cfg.artifact.frozen
    error('eegsl:Preprocess:UnfrozenICA','Real-time ICA must be frozen before apply.');
end
if strcmp(cfg.mode,'interactive-offline') && cfg.artifact.enabled
    if strcmpi(cfg.artifact.method,'auto')
        error('eegsl:Preprocess:InteractiveAutoICA', ...
            'Interactive offline artifact removal requires human-confirmed components.');
    elseif strcmpi(cfg.artifact.method,'ica') && ~cfg.artifact.human_confirmed
        error('eegsl:Preprocess:InteractiveUnconfirmedICA', ...
            'Interactive offline ICA requires human-confirmed components.');
    end
end
if strcmp(cfg.mode,'realtime') && isempty(cfg.quality_monitor.callback) && ...
        ~cfg.quality_monitor.allow_default
    error('eegsl:Preprocess:RealtimeQualityCallback', ...
        'Real-time mode requires quality_monitor.callback unless allow_default is true.');
end
end

function out = defaults()
out = struct();
out.mode = 'automated-offline';
out.filter = struct('enabled',false,'causal',false,'type','','order',[], ...
    'band',[],'design_callback',[]);
out.filter_callback = [];
out.downsample = struct('enabled',false,'callback',[],'rate',[]);
out.bad_channels = struct('enabled',false,'callback',[],'method','statistical');
out.artifact = struct('enabled',false,'callback',[],'method','regression', ...
    'frozen',false,'human_confirmed',false);
out.interpolation = struct('enabled',false,'callback',[],'method','spline');
out.spatial_filter = struct('enabled',false,'callback',[]);
out.bad_epochs = struct('enabled',false,'callback',[]);
out.quality_monitor = struct('callback',[],'thresholds',struct(),'allow_default',false);
end
function x = require_logical(x,name)
if ~(islogical(x)&&isscalar(x)), error('eegsl:Preprocess:Logical','%s must be scalar logical.',name); end
end
function out = merge_struct(base,override)
out = base;
for f = fieldnames(override)'
    n = f{1};
    if isstruct(override.(n)) && isfield(out,n) && isstruct(out.(n))
        out.(n) = merge_struct(out.(n),override.(n));
    else, out.(n) = override.(n); end
end
end
