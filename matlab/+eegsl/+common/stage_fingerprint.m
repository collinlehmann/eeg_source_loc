function fp = stage_fingerprint(stage, cfg)
%STAGE_FINGERPRINT Hash only configuration consumed by a named cache stage.
stage = char(stage);
switch stage
    case 'source_space'
        parts = struct('schema_version',cfg.schema_version,'source',cfg.source);
    case 'stiffness'
        parts = struct('engine',cfg.forward.engine, ...
            'headmodel',get_nested(cfg.forward,'fieldtrip','headmodel'));
    case 'transfer'
        parts = struct('engine',cfg.forward.engine, ...
            'vol_sens',get_nested(cfg.forward,'fieldtrip','vol_sens'));
    case 'leadfield'
        parts = struct('engine',cfg.forward.engine,'orientation',cfg.forward.orientation, ...
            'leadfield',get_nested(cfg.forward,'fieldtrip','leadfield'));
    case 'noise_covariance'
        parts = struct('paradigm',cfg.paradigm,'noise',cfg.noise,'reference',cfg.reference);
    case 'inverse_operator'
        parts = struct('inverse',cfg.inverse,'reference',cfg.reference);
    case 'normalization'
        parts = normalization_core(cfg.normalization);
    case 'petra'
        parts = cfg.petra;
    case {'synthetic.source_space','synthetic.leadfield','synthetic.sources', ...
            'synthetic.sensor_data','synthetic.source_estimate'}
        parts = synthetic_core(cfg.synthetic);
    case 'synthetic.noise_covariance'
        parts = struct('synthetic',synthetic_core(cfg.synthetic), ...
            'paradigm',cfg.paradigm,'noise',cfg.noise,'reference',cfg.reference);
    case 'synthetic.inverse_operator'
        parts = struct('synthetic',synthetic_core(cfg.synthetic), ...
            'inverse',cfg.inverse,'reference',cfg.reference);
    case 'synthetic.normalization'
        parts = normalization_core(cfg.normalization);
    otherwise
        error('eegsl:Cache:UnknownStage','Unknown cache stage: %s.',stage);
end
fp = eegsl.common.content_hash(strip_handles(parts));
end

function out = normalization_core(s)
out = s;
remove = intersect(fieldnames(out),{'enabled','seed'});
if ~isempty(remove), out = rmfield(out,remove); end
end

function out = synthetic_core(s)
out = s;
remove = intersect(fieldnames(out), ...
    {'sensor_orientation','source_orientation','normalization','cache_prefix','enabled'});
if ~isempty(remove), out = rmfield(out,remove); end
end

function value = get_nested(s,parent,child)
if isfield(s,parent) && isstruct(s.(parent)) && isfield(s.(parent),child) ...
        && isstruct(s.(parent).(child))
    value = s.(parent).(child);
else
    value = struct();
end
end

function value = strip_handles(value)
if isa(value,'function_handle')
    value = func2str(value);
elseif isstruct(value)
    fields = fieldnames(value);
    for n = 1:numel(value)
        for k = 1:numel(fields)
            value(n).(fields{k}) = strip_handles(value(n).(fields{k}));
        end
    end
elseif iscell(value)
    for k = 1:numel(value), value{k} = strip_handles(value{k}); end
end
end
