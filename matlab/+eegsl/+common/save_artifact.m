function [path, metadata] = save_artifact(cfg, kind, key, artifact, metadata, stage)
%SAVE_ARTIFACT Atomically save a validated cache artifact on Windows/macOS.
if nargin < 5 || isempty(metadata), metadata=struct(); end
cfg = eegsl.validate_config(cfg);
if ~cfg.cache.enabled, error('eegsl:Cache:Disabled','Cache writes are disabled.'); end
if cfg.cache.read_only, error('eegsl:Cache:ReadOnly','Cannot write while cache.read_only is true.'); end
path = eegsl.common.artifact_path(cfg,kind,key);
folder=fileparts(path); if ~isfolder(folder)&&~mkdir(folder), error('eegsl:Cache:CreateDirectory','Could not create cache directory: %s',folder); end
eegsl.common.cleanup_cache_temps(cfg,folder);
if isfile(path)&&~cfg.cache.overwrite, error('eegsl:Cache:Exists','Artifact already exists and overwrite is disabled: %s',path); end
lock = eegsl.common.acquire_cache_lock(cfg,path); lock_cleanup=onCleanup(@()eegsl.common.release_cache_lock(lock)); %#ok<NASGU>
if isfile(path)&&~cfg.cache.overwrite, error('eegsl:Cache:Exists','Artifact already exists and overwrite is disabled: %s',path); end
metadata=normalize_metadata(metadata);
if nargin >= 6 && ~isempty(stage)
    metadata.configuration_stage = char(stage);
    metadata.configuration_hash = eegsl.common.stage_fingerprint(stage,cfg);
else
    metadata.configuration_stage = '__full__';
    metadata.configuration_hash = eegsl.common.cache_config_hash(cfg);
end
cache_info=struct('kind',char(kind),'key',char(key),'schema_version',cfg.cache.version, ...
    'created_utc',utc_stamp(),'matlab_version',version,'artifact_class',class(artifact), ...
    'metadata_hash',eegsl.common.content_hash(metadata)); %#ok<NASGU>
tmp=[tempname(folder) '.tmp-' char(java.util.UUID.randomUUID()) '.mat'];
cleanup=onCleanup(@()delete_if_exists(tmp)); %#ok<NASGU>
try
    save(tmp,'artifact','metadata','cache_info','-mat');
    [ok,msg]=movefile(tmp,path,'f');
    if ~ok, error('eegsl:Cache:Commit','Could not commit cache artifact: %s',msg); end
catch err
    error('eegsl:Cache:Write','Failed to save cache artifact %s: %s',path,err.message);
end
end
function metadata=normalize_metadata(metadata), if ~isstruct(metadata), metadata=struct('value',metadata); end; end
function stamp=utc_stamp(), stamp=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX')); end
function delete_if_exists(p), if ~isempty(p)&&isfile(p), try, delete(p); catch, end, end; end
