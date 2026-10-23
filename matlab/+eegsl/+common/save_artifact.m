function [path, metadata] = save_artifact(cfg, kind, key, artifact, metadata)
%SAVE_ARTIFACT Atomically save a cache artifact on Windows or macOS.
%   Artifacts are MAT files containing artifact, metadata, and cache_info.
%   Writes use a same-directory temporary file followed by movefile so a
%   reader never observes a partially written final artifact.
if nargin < 5 || isempty(metadata), metadata = struct(); end
if ~isstruct(cfg) || ~isfield(cfg,'cache'), error('eegsl:Cache:Config','Canonical cache config is required.'); end
if isfield(cfg.cache,'enabled') && ~cfg.cache.enabled
    error('eegsl:Cache:Disabled','Cache writes are disabled.');
end
if isfield(cfg.cache,'read_only') && cfg.cache.read_only
    error('eegsl:Cache:ReadOnly','Cannot write while cache.read_only is true.');
end
path = eegsl.common.artifact_path(cfg,kind,key);
if isfile(path) && isfield(cfg.cache,'overwrite') && ~cfg.cache.overwrite
    error('eegsl:Cache:Exists','Artifact already exists and overwrite is disabled: %s',path);
end
folder = fileparts(path);
if ~isfolder(folder) && ~mkdir(folder)
    error('eegsl:Cache:CreateDirectory','Could not create cache directory: %s',folder);
end
cache_info = struct('kind',char(kind),'key',char(key), ...
    'schema_version',get_or(cfg.cache,'version','v1'), ...
    'created_utc',utc_stamp(),'matlab_version',version, ...
    'artifact_class',class(artifact)); %#ok<NASGU>
metadata = normalize_metadata(metadata);
tmp = [tempname(folder) '.mat'];
cleanup = onCleanup(@()delete_if_exists(tmp)); %#ok<NASGU>
try
    save(tmp,'artifact','metadata','cache_info','-mat');
    [ok,msg] = movefile(tmp,path,'f');
    if ~ok, error('eegsl:Cache:Commit','Could not commit cache artifact: %s',msg); end
catch err
    error('eegsl:Cache:Write','Failed to save cache artifact %s: %s',path,err.message);
end
end

function metadata = normalize_metadata(metadata)
if ~isstruct(metadata), metadata = struct('value',metadata); end
end
function value = get_or(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value = s.(name); else, value = default; end
end
function stamp = utc_stamp()
stamp = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
function delete_if_exists(path)
if ~isempty(path) && isfile(path), delete(path); end
end
