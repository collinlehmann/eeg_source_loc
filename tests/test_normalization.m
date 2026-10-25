function tests = test_normalization()
%TEST_NORMALIZATION Reproducibility and estimator behavior for frozen factors.
rs = RandStream('twister','Seed',5);
X = randn(rs,3*40,20000);
cfg = eegsl.default_config();
cfg.normalization.enabled = true;
cfg.normalization.orientation = 'free';
cfg.normalization.subsamples = 20;
cfg.normalization.subsample_size = 10000;
cfg.normalization.minimum_samples = 1000;
cfg.normalization.seed = 31;

lastwarn('');
[op,info] = eegsl.normalization.build_normalization(X,cfg);
[~,warningId] = lastwarn;
Y = eegsl.normalization.apply_normalization(op,X);
pointMedian = median(Y,2);
tests.background_near_one = all(pointMedian >= 0.9 & pointMedian <= 1.25);
tests.no_false_stable_warning = ~strcmp(warningId,'eegsl:Normalization:StableState');
tests.operator_shape = numel(op.mu) == 40 && numel(op.sigma) == 40;
tests.shape = isequal(size(Y),[40 20000]);
tests.positive = all(Y(:) >= 0);
tests.metadata = strcmp(info.stage,'normalization') && ~isempty(op.operator_id);

elevated = X;
elevated(1:3,1:14000) = 5*elevated(1:3,1:14000);
lastwarn('');
[~,stableInfo] = eegsl.normalization.build_normalization(elevated,cfg);
[~,warningId] = lastwarn;
tests.detects_stable_point = strcmp(warningId,'eegsl:Normalization:StableState') && ...
    stableInfo.stable_fraction(1)>0.5 && ismember(1,stableInfo.stable_points);

[opAgain,~] = eegsl.normalization.build_normalization(X,cfg);
tests.deterministic = isequal(op.mu,opAgain.mu) && isequal(op.sigma,opAgain.sigma) && ...
    strcmp(op.operator_id,opAgain.operator_id);
cfg.normalization.seed = 32;
opDifferent = eegsl.normalization.build_normalization(X,cfg);
tests.seed_sensitive_id = ~strcmp(op.operator_id,opDifferent.operator_id);

trialData = struct('trial',{{X(:,1:500),X(:,501:1000)}});
trialOutput = eegsl.normalization.apply_normalization(op,trialData);
tests.trial_roundtrip = isfield(trialOutput,'trial') && ~isfield(trialOutput,'avg') && ...
    numel(trialOutput.trial)==2 && isequal(size(trialOutput.trial{2}),[40 500]);

cfg.normalization.enabled = false;
caught = false;
try
    eegsl.normalization.build_normalization(X,cfg);
catch err
    caught = strcmp(err.identifier,'eegsl:Normalization:Disabled');
end
tests.opt_in = caught;
assert_test_checks(tests,'test_normalization');
tests.all_passed = true;
end
