function cfg = validate_config(cfg)
%VALIDATE_CONFIG Validate preprocessing execution mode and adapter seams.
if nargin < 1 || isempty(cfg), cfg = struct(); end
cfg = merge_struct(defaults(),cfg);
cfg.mode = lower(char(cfg.mode));
if ~ismember(cfg.mode,{'interactive-offline','automated-offline','realtime'})
    error('eegsl:Preprocess:Mode','Unsupported preprocessing mode: %s.',cfg.mode);
end
if strcmp(cfg.mode,'realtime') && cfg.filter.enabled
    if ~cfg.filter.causal
        error('eegsl:Preprocess:NoncausalRealtime','Real-time filtering must be causal.');
    end
    if strcmpi(cfg.artifact.method,'ica') && ~cfg.artifact.frozen
        error('eegsl:Preprocess:UnfrozenICA','Real-time ICA must be frozen before apply.');
    end
end
if strcmp(cfg.mode,'interactive-offline') && strcmpi(cfg.artifact.method,'auto')
    error('eegsl:Preprocess:InteractiveAutoICA', ...
        'Interactive offline artifact removal requires human-confirmed components.');
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
out.quality_monitor = struct('callback',[],'thresholds',struct());
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
