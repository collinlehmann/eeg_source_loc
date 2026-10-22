function [labels_refined, info] = refine_skull_with_petra(cfg, charm_out, petra_vol)
%REFINE_SKULL_WITH_PETRA Safely refine charm skull labels with PETRA data.
%   This first implementation establishes the provenance and fallback seam.
%   It does not silently emulate registration, N4, or external segmentation.
%   Supply cfg.registration_callback and cfg.segmentation_callback to provide
%   explicitly validated subject-specific implementations.
if nargin < 1 || isempty(cfg), cfg = struct(); end
if nargin < 2 || isempty(charm_out)
    error('eegsl:PETRA:MissingCharm','charm_out is required.');
end
if ~isfield(charm_out,'labels')
    error('eegsl:PETRA:MissingLabels','charm_out.labels is required.');
end
labels_refined = charm_out.labels;
info = base_info(cfg);

if nargin < 3 || isempty(petra_vol)
    info.used = false;
    info.reason = 'no_petra';
    return;
end
if ~get_or(cfg,'enabled',true)
    info.used = false;
    info.reason = 'disabled';
    return;
end

try
    if ~isfield(cfg,'registration_callback') || ~isa(cfg.registration_callback,'function_handle')
        error('eegsl:PETRA:RegistrationAdapter', ...
            'A validated registration_callback is required; SPM/ANTs integration is not implicit.');
    end
    if ~isfield(cfg,'segmentation_callback') || ~isa(cfg.segmentation_callback,'function_handle')
        error('eegsl:PETRA:SegmentationAdapter', ...
            'A validated segmentation_callback is required; PETRA segmentation is not implicit.');
    end
    target = get_target(charm_out);
    [registered, regInfo] = cfg.registration_callback(petra_vol,target,cfg);
    [compactMask,cancellousMask,segInfo] = cfg.segmentation_callback(registered,charm_out,cfg);
    validate_masks(compactMask,cancellousMask,size(labels_refined),charm_out,cfg);
    labels_refined = apply_override(labels_refined,compactMask,cancellousMask,cfg);
    qc = run_qc(labels_refined,charm_out,compactMask,cancellousMask,cfg);
    info.registration = regInfo;
    info.segmentation = segInfo;
    info.qc = qc;
    if ~qc.pass
        labels_refined = charm_out.labels;
        info.used = false;
        info.reason = 'qc_failed';
        return;
    end
    info.used = true;
    info.reason = 'petra_refined';
catch err
    if ~get_or(cfg,'allow_fallback',true), rethrow(err); end
    labels_refined = charm_out.labels;
    info.used = false;
    info.reason = 'registration_error';
    info.error_identifier = err.identifier;
    info.error_message = err.message;
end
info.identity = eegsl.common.content_hash(struct('used',info.used, ...
    'reason',info.reason,'labels',labels_refined));
end

function info = base_info(cfg)
info = struct('used',false,'reason','','registration',struct(), ...
    'segmentation',struct(),'qc',struct(),'config',cfg, ...
    'identity','','implementation','adapter-only');
end
function target = get_target(charm)
if isfield(charm,'conformed_t1'), target = charm.conformed_t1;
elseif isfield(charm,'reference'), target = charm.reference;
else, target = charm; end
end
function validate_masks(compact,cancellous,sz,charm,cfg)
if ~isequal(size(compact),sz) || ~isequal(size(cancellous),sz)
    error('eegsl:PETRA:MaskShape','PETRA masks must match charm label dimensions.');
end
if any(compact(:) & cancellous(:))
    error('eegsl:PETRA:OverlappingMasks','Compact and cancellous masks overlap.');
end
if isfield(cfg,'skull_label') && ~isempty(cfg.skull_label)
    skull = charm.labels == cfg.skull_label;
    if any((compact(:)|cancellous(:)) & ~skull(:))
        error('eegsl:PETRA:BoundaryOwnership','PETRA masks may only overwrite charm skull voxels.');
    end
end
end
function labels = apply_override(labels,compact,cancellous,cfg)
compactLabel = get_or(cfg,'compact_label',max(labels(:))+1);
cancellousLabel = get_or(cfg,'cancellous_label',compactLabel+1);
labels(compact) = compactLabel;
labels(cancellous) = cancellousLabel;
end
function qc = run_qc(labels,charm,compact,cancellous,cfg)
qc = struct('pass',true,'dice',NaN,'surface_distance_mean',NaN, ...
    'surface_distance95',NaN,'thresholds',struct());
if isfield(cfg,'qc_callback') && isa(cfg.qc_callback,'function_handle')
    qc = cfg.qc_callback(labels,charm,compact,cancellous,cfg);
    if ~isfield(qc,'pass'), qc.pass = false; end
    return;
end
% Without a validated QC callback, only enforce structural checks here. The
% production PETRA path should provide quantitative surface-distance and Dice.
if ~any(compact(:)|cancellous(:)), qc.pass = false; end
end
function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
