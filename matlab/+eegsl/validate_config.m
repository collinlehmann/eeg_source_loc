function cfg = validate_config(cfg)
%VALIDATE_CONFIG Validate and normalize pipeline configuration.
if nargin == 0 || isempty(cfg)
    cfg = eegsl.default_config();
else
    cfg = merge_struct(eegsl.default_config(), cfg);
end

if ~isfield(cfg,'paradigm') || isempty(cfg.paradigm)
    error('eegsl:Config:MissingParadigm', ...
        'cfg.paradigm is required and must be ''task'' or ''resting''.');
end
cfg.paradigm = lower(char(cfg.paradigm));
if ~ismember(cfg.paradigm, {'task','resting'})
    error('eegsl:Config:InvalidParadigm','Unsupported paradigm: %s.',cfg.paradigm);
end

cfg.source.mode = lower(char(cfg.source.mode));
if ~ismember(cfg.source.mode, {'wholebrain','cortical'})
    error('eegsl:Config:InvalidSourceMode','Unsupported source mode: %s.',cfg.source.mode);
end
cfg.forward.engine = lower(char(cfg.forward.engine));
if ~ismember(cfg.forward.engine, {'simbio','duneuro','analytic'})
    error('eegsl:Config:InvalidEngine','Unsupported forward engine: %s.',cfg.forward.engine);
end
if strcmp(cfg.paradigm,'resting') && strcmpi(char(cfg.noise.route),'baseline')
    error('eegsl:Config:RestingBaseline', ...
        'A baseline noise route is invalid for resting data.');
end
if cfg.normalization.enabled && cfg.normalization.subsamples < 1
    error('eegsl:Config:NormalizationSubsamples','subsamples must be positive.');
end
end

function out = merge_struct(base, override)
out = base;
fields = fieldnames(override);
for k = 1:numel(fields)
    f = fields{k};
    if isstruct(override.(f)) && isfield(base,f) && isstruct(base.(f))
        out.(f) = merge_struct(base.(f), override.(f));
    else
        out.(f) = override.(f);
    end
end
end
