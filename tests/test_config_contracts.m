function tests = test_config_contracts()
%TEST_CONFIG_CONTRACTS Verify root-schema defaults, normalization, and errors.
cfg = eegsl.validate_config(struct('paradigm','resting'));
tests.defaults = strcmp(cfg.schema_version,'1.0') && ...
    strcmp(cfg.source.mode,'wholebrain') && strcmp(cfg.forward.engine,'simbio');
tests.resting_default_route = isempty(cfg.noise.route);

task = eegsl.validate_config(struct('paradigm','task', ...
    'noise',struct('route','baseline','baseline',[-0.2 0])));
tests.task_baseline = strcmp(task.noise.route,'baseline');

caught = false;
try, eegsl.validate_config(struct('paradigm','resting', ...
    'noise',struct('route','baseline','baseline',[-1 0])));
catch err, caught = strcmp(err.identifier,'eegsl:Config:RestingBaseline'); end
tests.resting_baseline_rejected = caught;

caught = false;
try, eegsl.validate_config(struct('paradigm','task', ...
    'source',struct('min_points',10,'max_points',5)));
catch err, caught = strcmp(err.identifier,'eegsl:Config:SourcePointRange'); end
tests.point_range_rejected = caught;

caught = false;
try, eegsl.validate_config(struct('paradigm','task', ...
    'execution',struct('mode','realtime','realtime',false)));
catch err, caught = strcmp(err.identifier,'eegsl:Config:ExecutionMismatch'); end
tests.execution_mismatch_rejected = caught;

assert_test_checks(tests,'test_config_contracts');
tests.all_passed = true;
end
