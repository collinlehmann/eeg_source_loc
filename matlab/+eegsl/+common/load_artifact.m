function [artifact, metadata, cache_info] = load_artifact(cfg, kind, key)
%LOAD_ARTIFACT Load and validate a cache artifact.
if ~isstruct(cfg) || ~isfield(cfg,'cache'), error('eegsl:Cache:Config','Canonical cache config is required.'); end
path = eegsl.common.artifact_path(cfg,kind,key);
if ~isfile(path), error('eegsl:Cache:NotFound','Cache artifact not found: %s',path); end
try
    loaded = load(path,'artifact','metadata','cache_info');
catch err
    error('eegsl:Cache:Read','Could not read cache artifact %s: %s',path,err.message);
end
required = {'artifact','metadata','cache_info'};
for k = 1:numel(required)
    if ~isfield(loaded,required{k})
        error('eegsl:Cache:Invalid','Cache artifact is missing field %s: %s',required{k},path);
    end
end
cache_info = loaded.cache_info;
expectedVersion = get_or(cfg.cache,'version','v1');
if isfield(cache_info,'schema_version') && ~strcmp(char(cache_info.schema_version),char(expectedVersion))
    error('eegsl:Cache:Version','Cache schema mismatch: found %s, expected %s.', ...
        char(cache_info.schema_version),char(expectedVersion));
end
if isfield(cache_info,'kind') && ~strcmp(char(cache_info.kind),char(kind))
    error('eegsl:Cache:Kind','Cache artifact kind does not match requested kind.');
end
if isfield(cache_info,'key') && ~strcmp(char(cache_info.key),char(key))
    error('eegsl:Cache:Key','Cache artifact key does not match requested key.');
end
artifact = loaded.artifact;
metadata = loaded.metadata;
end
function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
