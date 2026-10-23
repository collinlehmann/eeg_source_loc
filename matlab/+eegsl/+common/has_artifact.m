function tf = has_artifact(cfg, kind, key)
%HAS_ARTIFACT Return true when a valid cache artifact exists.
path = eegsl.common.artifact_path(cfg,kind,key);
tf = isfile(path);
end
