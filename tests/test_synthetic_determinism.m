function tests = test_synthetic_determinism()
%TEST_SYNTHETIC_DETERMINISM Same seed reproduces outputs; different seed changes them.
tol = 1e-9;
[cfgA, rootA] = synthetic_e2e_cfg(11);
[cfgB, rootB] = synthetic_e2e_cfg(11);   % separate cache: no cache reuse involved
[cfgC, rootC] = synthetic_e2e_cfg(12);
cleanup = onCleanup(@()cellfun(@(r)rmdir(r,'s'),{rootA,rootB,rootC})); %#ok<NASGU>

a = eegsl.validate_synthetic_e2e(cfgA);
b = eegsl.validate_synthetic_e2e(cfgB);
c = eegsl.validate_synthetic_e2e(cfgC);

tests.same_seed_sources = norm(a.synthetic.sources - b.synthetic.sources,'fro') < tol;
tests.same_seed_sensor = norm(a.synthetic.sensor_noisy - b.synthetic.sensor_noisy,'fro') < tol;
tests.same_seed_estimate = norm(a.inverse.estimate - b.inverse.estimate,'fro') < tol;
tests.same_seed_hash = strcmp(a.provenance.output_hash,b.provenance.output_hash);
tests.diff_seed_sources = norm(a.synthetic.sources - c.synthetic.sources,'fro') > 1e-3;
tests.diff_seed_sensor = norm(a.synthetic.sensor_noisy - c.synthetic.sensor_noisy,'fro') > 1e-3;
tests.diff_seed_hash = ~strcmp(a.provenance.output_hash,c.provenance.output_hash);

tests.all_passed = all(structfun(@(x)logical(x),tests));
if ~tests.all_passed
    error('eegsl:Tests:SyntheticDeterminismFailure','Synthetic determinism test failed.');
end
end
