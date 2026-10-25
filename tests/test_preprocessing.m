function tests = test_preprocessing()
%TEST_PREPROCESSING Dependency-free preprocessing contract tests.
X = randn(4,100);
identity = @(x,varargin)x;

cfg = struct('mode','automated-offline', ...
    'filter',struct('enabled',true,'causal',false,'type','butterworth', ...
        'order',2,'band',[1 40]), ...
    'filter_callback',identity);
[clean,info] = eegsl.preprocessing.preprocess(X,cfg);
tests.offline_identity = isequal(size(clean),size(X));
tests.provenance = strcmp(info.stage,'preprocessing') && ~info.causal;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','realtime', ...
        'filter',struct('enabled',true,'causal',false,'type','butterworth', ...
            'order',2,'band',[1 40]),'filter_callback',identity, ...
        'quality_monitor',struct('allow_default',true)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:NoncausalRealtime');
end
tests.noncausal_rejected = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','realtime','filter_callback',identity));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:FilterFlagMismatch');
end
tests.filter_flag_mismatch = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('filter',struct('enabled',true)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:FilterAdapter');
end
tests.filter_adapter_required = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('filter',struct('enabled',true), ...
        'filter_callback',identity));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:FilterProvenance');
end
tests.filter_provenance_required = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','realtime', ...
        'artifact',struct('enabled',true,'method','ica','frozen',false), ...
        'quality_monitor',struct('allow_default',true)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:UnfrozenICA');
end
tests.unfrozen_ica_rejected = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','interactive-offline', ...
        'artifact',struct('enabled',true,'method','ica','human_confirmed',false)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:InteractiveUnconfirmedICA');
end
tests.interactive_ica_confirmation = caught;

caught = false;
try
    eegsl.preprocessing.validate_config(struct('mode','realtime'));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:RealtimeQualityCallback');
end
tests.realtime_quality_callback = caught;

caught = false;
try
    eegsl.preprocessing.preprocess(X,struct('mode','realtime','bad_epochs', ...
        struct('enabled',true,'callback',@(x,c)deal([],struct())), ...
        'quality_monitor',struct('allow_default',true)));
catch err
    caught = strcmp(err.identifier,'eegsl:Preprocess:RealtimeEpochRejection');
end
tests.realtime_epoch_rejected = caught;

q = eegsl.preprocessing.quality_monitor(X,struct());
tests.quality = q.pass && q.n_channels == 4 && ...
    strcmp(q.reason,'finite_check_passed') && strcmp(q.monitor,'default_finite_only');

icaCfg = struct('mode','automated-offline','artifact',struct('enabled',true, ...
    'method','ica','human_confirmed',false,'callback',identity));
[~,icaInfo] = eegsl.preprocessing.preprocess(X,icaCfg);
tests.ica_provenance = ~icaInfo.ica_human_confirmed && ...
    any(strcmp(icaInfo.flags,'ica_components_not_human_confirmed'));
assert_test_checks(tests,'test_preprocessing');
tests.all_passed = true;
end
