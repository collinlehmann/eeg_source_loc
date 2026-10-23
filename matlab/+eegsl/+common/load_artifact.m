function [artifact, metadata, cache_info] = load_artifact(cfg, kind, key)
%LOAD_ARTIFACT Load and validate a cache artifact, including integrity metadata.
cfg=eegsl.validate_config(cfg); path=eegsl.common.artifact_path(cfg,kind,key);
if ~isfile(path), error('eegsl:Cache:NotFound','Cache artifact not found: %s',path); end
try, loaded=load(path,'artifact','metadata','cache_info'); catch err, error('eegsl:Cache:Read','Could not read cache artifact %s: %s',path,err.message); end
required={'artifact','metadata','cache_info'}; for k=1:numel(required), if ~isfield(loaded,required{k}), error('eegsl:Cache:Invalid','Cache artifact is missing field %s: %s',required{k},path); end, end
cache_info=loaded.cache_info;
if ~isstruct(cache_info)||~isfield(cache_info,'schema_version')||~strcmp(char(cache_info.schema_version),char(cfg.cache.version)), error('eegsl:Cache:Version','Cache schema mismatch.'); end
if ~isfield(cache_info,'kind')||~strcmp(char(cache_info.kind),char(kind)), error('eegsl:Cache:Kind','Cache artifact kind does not match requested kind.'); end
if ~isfield(cache_info,'key')||~strcmp(char(cache_info.key),char(key)), error('eegsl:Cache:Key','Cache artifact key does not match requested key.'); end
metadata=loaded.metadata;
if isfield(cache_info,'metadata_hash') && ~strcmp(char(cache_info.metadata_hash),eegsl.common.content_hash(metadata)), error('eegsl:Cache:Corrupt','Cache metadata integrity check failed: %s',path); end
if isstruct(metadata)&&isfield(metadata,'configuration_hash')
    expected=eegsl.common.cache_config_hash(cfg);
    if ~strcmp(char(metadata.configuration_hash),expected), error('eegsl:Cache:ConfigurationMismatch','Cache artifact configuration does not match the requested configuration.'); end
end
artifact=loaded.artifact;
end
