function [clean, info] = preprocess(data, cfg)
%PREPROCESS Apply the dependency-light preprocessing orchestration.
%   Offline filtering is implemented only when explicit filter callbacks are
%   supplied; real-time mode requires a causal callback. Artifact removal,
%   interpolation, and spatial filtering are explicit seams.
if nargin < 2, cfg = struct(); end
if isempty(data), error('eegsl:Preprocess:MissingData','data is required.'); end
cfg = eegsl.preprocessing.validate_config(cfg);
mode = cfg.mode;

clean = data;
steps = {};
if cfg.filter.enabled
    clean = cfg.filter_callback(clean,cfg.filter);
    steps{end+1} = 'filter'; %#ok<AGROW>
end

if cfg.downsample.enabled
    if isempty(cfg.downsample.callback)
        error('eegsl:Preprocess:DownsampleAdapter','Downsampling requires an explicit callback.');
    end
    clean = cfg.downsample.callback(clean,cfg.downsample);
    steps{end+1} = 'downsample'; %#ok<AGROW>
end

if cfg.bad_channels.enabled
    if isempty(cfg.bad_channels.callback)
        error('eegsl:Preprocess:BadChannelAdapter','Bad-channel detection requires an explicit callback.');
    end
    [bad, badInfo] = cfg.bad_channels.callback(clean,cfg.bad_channels);
    clean = mark_bad_channels(clean,bad);
else
    bad = {};
    badInfo = struct();
end

if cfg.artifact.enabled
    if isempty(cfg.artifact.callback)
        error('eegsl:Preprocess:ArtifactAdapter','Artifact removal requires an explicit callback.');
    end
    clean = cfg.artifact.callback(clean,cfg.artifact);
    steps{end+1} = 'artifact'; %#ok<AGROW>
end

if cfg.interpolation.enabled
    if isempty(cfg.interpolation.callback)
        error('eegsl:Preprocess:InterpolationAdapter','Interpolation requires an explicit callback.');
    end
    clean = cfg.interpolation.callback(clean,bad,cfg.interpolation);
    steps{end+1} = 'interpolation'; %#ok<AGROW>
end

if cfg.spatial_filter.enabled
    if isempty(cfg.spatial_filter.callback)
        error('eegsl:Preprocess:SpatialFilterAdapter','Spatial filtering requires an explicit callback.');
    end
    clean = cfg.spatial_filter.callback(clean,cfg.spatial_filter);
    steps{end+1} = 'spatial_filter'; %#ok<AGROW>
end

if cfg.bad_epochs.enabled
    if strcmp(mode,'realtime')
        error('eegsl:Preprocess:RealtimeEpochRejection', ...
            'Real-time preprocessing cannot reject future epochs; use quality monitoring.');
    end
    if isempty(cfg.bad_epochs.callback)
        error('eegsl:Preprocess:BadEpochAdapter','Bad-epoch detection requires an explicit callback.');
    end
    [badEpochs, epochInfo] = cfg.bad_epochs.callback(clean,cfg.bad_epochs);
else
    badEpochs = [];
    epochInfo = struct();
end

quality = eegsl.preprocessing.quality_monitor(clean,cfg.quality_monitor);
info = eegsl.common.provenance('preprocessing',struct( ...
    'mode',mode,'steps',{steps},'bad_channels',{bad}, ...
    'bad_channel_info',badInfo,'bad_epochs',badEpochs, ...
    'bad_epoch_info',epochInfo,'quality',quality, ...
    'filter',cfg.filter,'artifact',cfg.artifact, ...
    'causal',cfg.filter.causal));
if strcmp(mode,'automated-offline') && cfg.artifact.enabled && ...
        strcmpi(cfg.artifact.method,'ica')
    info.ica_human_confirmed = cfg.artifact.human_confirmed;
    if ~cfg.artifact.human_confirmed
        info.flags = {'ica_components_not_human_confirmed'};
    else
        info.flags = {};
    end
end
if strcmp(mode,'realtime') && ~quality.pass
    info.control_gate = false;
else
    info.control_gate = true;
end
end

function data = mark_bad_channels(data,bad)
if ~isstruct(data) || isempty(bad), return; end
if ischar(bad), bad = {bad}; end
if isfield(data,'label')
    data.badchannel = bad;
end
end
