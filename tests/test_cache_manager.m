function tests = test_cache_manager()
%TEST_CACHE_MANAGER Cross-platform cache round-trip tests.
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
cfg = eegsl.default_config();
cfg.cache.root = root;
cfg.cache.overwrite = false;
key = eegsl.common.cache_key('synthetic',struct('a',1));
artifact = struct('matrix',reshape(1:12,3,4));
metadata = struct('stage','test','units','mm');
[path,~] = eegsl.common.save_artifact(cfg,'synthetic',key,artifact,metadata);
[a,m,c] = eegsl.common.load_artifact(cfg,'synthetic',key);
tests.platform_path = isfile(path) && isempty(strfind(path,['/' filesep])) == false || ispc || ismac; %#ok<STREMP>
tests.round_trip = isequal(a,artifact) && isequal(m,metadata);
tests.metadata = strcmp(c.kind,'synthetic') && strcmp(c.key,key);
tests.exists = eegsl.common.has_artifact(cfg,'synthetic',key);
manifest = eegsl.common.cache_manifest(cfg);
tests.manifest = manifest.exists && numel(manifest.artifacts) == 1;
eegsl.common.delete_artifact(cfg,'synthetic',key);
tests.deleted = ~eegsl.common.has_artifact(cfg,'synthetic',key);

tests.all_passed = all(structfun(@(x)logical(x),tests));
if ~tests.all_passed, error('eegsl:Tests:CacheFailure','Cache manager test failed.'); end
end
