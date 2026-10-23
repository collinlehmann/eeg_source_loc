function delete_artifact(cfg, kind, key)
%DELETE_ARTIFACT Delete one cache artifact without shell commands.
path = eegsl.common.artifact_path(cfg,kind,key);
if isfile(path), delete(path); end
end
