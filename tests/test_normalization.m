function tests = test_normalization()
%TEST_NORMALIZATION Dependency-free tests for frozen normalization.
rng(19);
X = randn(9,1800);
cfg = eegsl.default_config();
cfg.normalization.enabled = true;
cfg.normalization.orientation = 'free';
cfg.normalization.subsamples = 5;
cfg.normalization.subsample_size = 900;
cfg.normalization.minimum_samples = 100;
[op,info] = eegsl.normalization.build_normalization(X,cfg);
Y = eegsl.normalization.apply_normalization(op,X);
tests.operator = numel(op.mu) == 3 && numel(op.sigma) == 3;
tests.shape = isequal(size(Y),[3 1800]);
tests.positive = all(Y(:) >= 0);
tests.metadata = strcmp(info.stage,'normalization') && ~isempty(op.operator_id);

cfg.normalization.enabled = false;
caught = false;
try, eegsl.normalization.build_normalization(X,cfg); catch err, caught = strcmp(err.identifier,'eegsl:Normalization:Disabled'); end
tests.opt_in = caught;
assert_test_checks(tests,'test_normalization');
tests.all_passed = true;
end
