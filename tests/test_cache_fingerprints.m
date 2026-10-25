function tests = test_cache_fingerprints()
%TEST_CACHE_FINGERPRINTS Verify stage-scoped cache identity and legacy behavior.
[cfg, root] = synthetic_e2e_cfg(9);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
first = eegsl.validate_synthetic_e2e(cfg);

cfg.progress.interval_seconds = 5;
second = eegsl.validate_synthetic_e2e(cfg);
tests.unrelated_change_hits = second.cache.misses == 0;

cfg.inverse.depth_exponent = 0.5;
third = eegsl.validate_synthetic_e2e(cfg);
missedStages = third.cache.stages(~cellfun(@(x)x.cache_hit,third.cache.stages));
misses = cellfun(@(x)x.stage,missedStages,'UniformOutput',false);
tests.inverse_change_scoped = isequal(sort(misses),sort({'inverse_operator','source_estimate'}));

cfg.inverse.depth_exponent = 0.8;
cfg.normalization.enabled = true;
fourth = eegsl.validate_synthetic_e2e(cfg);
tests.normalization_toggle = fourth.cache.misses == 1 && ...
    strcmp(fourth.cache.stages{end}.stage,'normalization');

key = eegsl.common.cache_key('legacy',1);
eegsl.common.save_artifact(cfg,'legacy',key,struct('value',42),struct());
loaded = eegsl.common.load_artifact(cfg,'legacy',key);
tests.legacy_save_load = loaded.value == 42;

caught = false;
try
    eegsl.common.stage_fingerprint('bogus',cfg);
catch err
    caught = strcmp(err.identifier,'eegsl:Cache:UnknownStage');
end
tests.unknown_stage = caught;
tests.first_run_completed = first.cache.misses == 7;

assert_test_checks(tests,'test_cache_fingerprints');
tests.all_passed = true;
end
