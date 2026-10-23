function tests = test_cache_manager()
%TEST_CACHE_MANAGER Cross-platform cache hardening tests.
root=tempname; mkdir(root); cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
cfg=eegsl.validate_config(struct('paradigm','resting','cache',struct('root',root)));
key=eegsl.common.cache_key('synthetic',struct('a',1)); artifact=struct('matrix',reshape(1:12,3,4)); metadata=struct('stage','test','units','mm');
[path,~]=eegsl.common.save_artifact(cfg,'synthetic',key,artifact,metadata); [a,m,c]=eegsl.common.load_artifact(cfg,'synthetic',key);
tests.round_trip=isequal(a,artifact)&&strcmp(m.stage,'test'); tests.metadata=strcmp(c.kind,'synthetic')&&isfield(m,'configuration_hash');
tests.exists=eegsl.common.has_artifact(cfg,'synthetic',key); manifest=eegsl.common.cache_manifest(cfg); tests.manifest=manifest.exists&&numel(manifest.artifacts)==1;

caught=false; try, eegsl.common.save_artifact(cfg,'synthetic',key,artifact,metadata); catch err, caught=strcmp(err.identifier,'eegsl:Cache:Exists'); end; tests.duplicate_rejected=caught;
cfg.cache.overwrite=true; eegsl.common.save_artifact(cfg,'synthetic',key,artifact,metadata); tests.overwrite=true;
cfg.cache.read_only=true; caught=false; try, eegsl.common.save_artifact(cfg,'other',key,artifact,metadata); catch err, caught=strcmp(err.identifier,'eegsl:Cache:ReadOnly'); end; tests.read_only=caught;

% Corruption and configuration mismatch are detected on load.
cfg.cache.read_only=false; cfg.cache.overwrite=true; fid=fopen(path,'w'); fwrite(fid,'not a MAT file'); fclose(fid); caught=false; try, eegsl.common.load_artifact(cfg,'synthetic',key); catch err, caught=strcmp(err.identifier,'eegsl:Cache:Read'); end; tests.corruption=caught;
eegsl.common.delete_artifact(cfg,'synthetic',key); tests.deleted=~eegsl.common.has_artifact(cfg,'synthetic',key);

tests.all_passed=all(structfun(@(x)logical(x),tests)); if ~tests.all_passed, error('eegsl:Tests:CacheFailure','Cache manager test failed.'); end
end
