function [labels_refined, info] = refine_skull_with_petra(cfg, charm_out, petra_vol)
%REFINE_SKULL_WITH_PETRA Refine skull labels only after mandatory QC succeeds.
if nargin < 1 || isempty(cfg), cfg = struct(); end
if nargin < 2 || isempty(charm_out)
    error('eegsl:PETRA:MissingCharm','charm_out is required.');
end
if ~isstruct(charm_out) || ~isfield(charm_out,'labels')
    error('eegsl:PETRA:MissingLabels','charm_out.labels is required.');
end
labels_refined = charm_out.labels;
pcfg = resolve_config(cfg);
info = base_info(pcfg);
if ~pcfg.enabled
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info,'disabled',pcfg);
    return;
end
if nargin < 3 || isempty(petra_vol)
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info,'no_petra',pcfg);
    return;
end
if isempty(pcfg.skull_label) || isempty(pcfg.compact_label) || ...
        isempty(pcfg.cancellous_label) || numel(unique([pcfg.skull_label, ...
        pcfg.compact_label,pcfg.cancellous_label])) ~= 3
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info,'config_error',pcfg);
    return;
end

if ~isa(pcfg.registration_callback,'function_handle')
    info = add_error(info,'eegsl:PETRA:RegistrationAdapter', ...
        'A registration_callback is required.');
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'registration_error',pcfg);
    return;
end
try
    [registered,regInfo] = pcfg.registration_callback(petra_vol,get_target(charm_out),pcfg);
catch err
    info = add_error(info,err.identifier,err.message);
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'registration_error',pcfg);
    return;
end
info.registration = regInfo;
if ~isa(pcfg.segmentation_callback,'function_handle')
    info = add_error(info,'eegsl:PETRA:SegmentationAdapter', ...
        'A segmentation_callback is required.');
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'segmentation_error',pcfg);
    return;
end
try
    [compact,cancellous,segInfo] = pcfg.segmentation_callback(registered,charm_out,pcfg);
catch err
    info = add_error(info,err.identifier,err.message);
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'segmentation_error',pcfg);
    return;
end
info.segmentation = segInfo;
[valid,maskError] = validate_masks(compact,cancellous,charm_out.labels,pcfg);
if ~valid
    info.mask_error = maskError;
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info,'mask_error',pcfg);
    return;
end

if ~isa(pcfg.qc_callback,'function_handle')
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'qc_unavailable',pcfg);
    return;
end
if isempty(pcfg.qc.dice_min) || isempty(pcfg.qc.surface_distance95_max)
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'qc_unconfigured',pcfg);
    return;
end
candidate = apply_override(charm_out.labels,compact,cancellous,pcfg);
try
    metrics = pcfg.qc_callback(candidate,charm_out,compact,cancellous,pcfg);
catch err
    info = add_error(info,err.identifier,err.message);
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'qc_unavailable',pcfg);
    return;
end
if ~isstruct(metrics) || ~isfield(metrics,'dice') || ...
        ~isfield(metrics,'surface_distance95') || ...
        ~(isnumeric(metrics.dice)&&isscalar(metrics.dice)) || ...
        ~(isnumeric(metrics.surface_distance95)&&isscalar(metrics.surface_distance95))
    info = add_error(info,'eegsl:PETRA:QCFormat', ...
        'qc_callback must return numeric scalar dice and surface_distance95 metrics.');
    [labels_refined,info] = finish(labels_refined,charm_out.labels,info, ...
        'qc_unavailable',pcfg);
    return;
end
passed = metrics.dice >= pcfg.qc.dice_min && ...
    metrics.surface_distance95 <= pcfg.qc.surface_distance95_max;
qc = struct('pass',passed,'dice',metrics.dice, ...
    'surface_distance95',metrics.surface_distance95, ...
    'thresholds',struct('dice_min',pcfg.qc.dice_min, ...
    'surface_distance95_max',pcfg.qc.surface_distance95_max));
if isfield(metrics,'surface_distance_mean')
    qc.surface_distance_mean = metrics.surface_distance_mean;
end
info.qc = qc;
if ~passed
    [labels_refined,info] = finish(charm_out.labels,charm_out.labels,info,'qc_failed',pcfg);
else
    [labels_refined,info] = finish(candidate,charm_out.labels,info,'petra_refined',pcfg);
end
end

function pcfg = resolve_config(cfg)
defaults = eegsl.default_config().petra;
if isstruct(cfg) && isfield(cfg,'petra') && isstruct(cfg.petra)
    pcfg = merge_struct(defaults,cfg.petra);
elseif isstruct(cfg) && any(isfield(cfg, ...
        {'enabled','registration_callback','segmentation_callback'}))
    warning('eegsl:PETRA:LegacyConfig','Pass PETRA options in cfg.petra.');
    pcfg = merge_struct(defaults,cfg);
else
    pcfg = defaults;
end
end

function info = base_info(cfg)
info = struct('used',false,'reason','','registration',struct(), ...
    'segmentation',struct(),'qc',struct(),'config',cfg, ...
    'identity','','implementation','adapter-only');
end
function [labels,info] = finish(labels,original,info,reason,cfg)
info.used = strcmp(reason,'petra_refined');
info.reason = reason;
if ~info.used, labels=original; end
info.identity = eegsl.common.content_hash(struct('used',info.used, ...
    'reason',reason,'labels',labels));
if ~ismember(reason,{'petra_refined','disabled','no_petra'}) && ~cfg.allow_fallback
    error(['eegsl:PETRA:' reason_id(reason)], ...
        'PETRA refinement stopped: %s.',strrep(reason,'_',' '));
end
end
function info = add_error(info,id,message)
info.error_identifier = id;
info.error_message = message;
end
function target = get_target(charm)
if isfield(charm,'conformed_t1'), target=charm.conformed_t1;
elseif isfield(charm,'reference'), target=charm.reference;
else, target=charm; end
end
function [ok,reason] = validate_masks(compact,cancellous,labels,cfg)
ok=false; reason='';
if ~islogical(compact) || ~islogical(cancellous) || ...
        ~isequal(size(compact),size(labels)) || ~isequal(size(cancellous),size(labels))
    reason='incomplete_coverage'; return;
end
if any(compact(:)&cancellous(:)), reason='overlap'; return; end
skull = labels==cfg.skull_label;
unionMask = compact|cancellous;
if any(unionMask(:)&~skull(:)), reason='outside_skull'; return; end
if ~isequal(unionMask,skull), reason='incomplete_coverage'; return; end
ok=true;
end
function labels = apply_override(labels,compact,cancellous,cfg)
labels(compact)=cfg.compact_label;
labels(cancellous)=cfg.cancellous_label;
end
function id = reason_id(reason)
parts = strsplit(reason,'_');
id = [upper(parts{1}(1)) parts{1}(2:end)];
for k=2:numel(parts), id=[id upper(parts{k}(1)) parts{k}(2:end)]; end %#ok<AGROW>
end
function out = merge_struct(base,override)
out=base;
for f=fieldnames(override)'
    name=f{1};
    if isstruct(override.(name)) && isfield(out,name) && isstruct(out.(name))
        out.(name)=merge_struct(out.(name),override.(name));
    else
        out.(name)=override.(name);
    end
end
end
