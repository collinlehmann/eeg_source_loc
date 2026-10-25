function tests = test_preprocessing()
%TEST_PREPROCESSING Dependency-free preprocessing contract tests.
X = randn(4,100);
identity = @(x,varargin)x;

cfg = struct('mode','automated-offline', ...
    'filter',struct('enabled',true,'causal',false), ...
    'filter_callback',identity);
[clean,info] = eegsl.preprocessing.preprocess(X,cfg);
tests.offline_identity = isequal(size(clean),size(X));
tests.provenance = strcmp(info.stage,'preprocessing') && ~info.causal;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','realtime', ...
        'filter',struct('enabled',true,'causal',false)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:NoncausalRealtime');
end
tests.noncausal_rejected = caught;

caught = false;
try
    eegsl.preprocessing.preprocess(X,struct('mode','realtime','bad_epochs', ...
        struct('enabled',true,'callback',@(x,c)deal([],struct()))));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:RealtimeEpochRejection');
end
tests.realtime_epoch_rejected = caught;

q = eegsl.preprocessing.quality_monitor(X,struct());
tests.quality = q.pass && q.n_channels == 4;
assert_test_checks(tests,'test_preprocessing');
tests.all_passed = true;
end
