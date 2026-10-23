function tests = test_synthetic_validation()
%TEST_SYNTHETIC_VALIDATION Deterministic synthetic end-to-end pipeline tests.
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>

cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = root;
cfg.cache.enabled = true;
cfg.inverse.lambda = 0.05;
cfg.noise.route = 'diagonal';
cfg.synthetic.seed = 42;
cfg.synthetic.n_channels = 12;
cfg.synthetic.n_sources = 10;
cfg.synthetic.n_time = 300;
cfg.synthetic.active_sources = [1 2 6];
cfg.synthetic.deep_source_index = 6;

r1 = eegsl.run_synthetic_validation(cfg);
r2 = eegsl.run_synthetic_validation(cfg);

tests.cold_cache_has_misses = r1.cache.misses > 0;
tests.warm_cache_hits = r2.cache.hits >= r1.cache.misses;
tests.warm_cache_no_miss = r2.cache.misses == 0;
tests.deterministic_sensor = norm(r1.sensor.noisy_internal - r2.sensor.noisy_internal,'fro') < 1e-12;
tests.deterministic_estimate = norm(r1.estimate.estimate_internal - r2.estimate.estimate_internal,'fro') < 1e-12;
tests.hash_match = strcmp(r1.metrics.output_hash,r2.metrics.output_hash);
tests.metrics_present = isfield(r2.metrics,'sensor_reconstruction_error') && ...
    isfield(r2.metrics,'deep_source_localization_error');

cfg.synthetic.sensor_orientation = 'samples_by_channels';
cfg.synthetic.source_orientation = 'samples_by_components';
cfg.synthetic.seed = 43;
r3 = eegsl.run_synthetic_validation(cfg);
tests.sensor_orientation = isequal(size(r3.sensor.noisy),[cfg.synthetic.n_time cfg.synthetic.n_channels]);
tests.source_orientation = isequal(size(r3.truth.source),[cfg.synthetic.n_time 3*cfg.synthetic.n_sources]);

caught = false;
try
    corruptCfg = cfg;
    corruptCfg.synthetic.seed = 44;
    rCorrupt = eegsl.run_synthetic_validation(corruptCfg);
    sensorKey = stage_key(rCorrupt.cache.stages,'sensor_data');
    estimateKey = stage_key(rCorrupt.cache.stages,'source_estimate');
    eegsl.common.delete_artifact(corruptCfg,'synthetic',estimateKey);
    badSensor = rCorrupt.sensor;
    badSensor.noisy_internal = badSensor.noisy_internal.';
    corruptCfg.cache.overwrite = true;
    eegsl.common.save_artifact(corruptCfg,'synthetic',sensorKey,badSensor,struct('stage','sensor_data_corrupt'));
    eegsl.run_synthetic_validation(corruptCfg);
catch err
    caught = strcmp(err.identifier,'eegsl:Pipeline:SyntheticSensorDimension');
end
tests.malformed_dimension_error = caught;

caught = false;
try
    bad = cfg;
    bad.synthetic.active_sources = cfg.synthetic.n_sources + 1;
    eegsl.validate_config(bad);
catch err
    caught = strcmp(err.identifier,'eegsl:Config:SyntheticActiveSourceRange');
end
tests.invalid_active_sources = caught;

caught = false;
try
    bad = cfg;
    bad.synthetic.deep_source_index = cfg.synthetic.n_sources + 2;
    eegsl.validate_config(bad);
catch err
    caught = strcmp(err.identifier,'eegsl:Config:SyntheticDeepSourceRange');
end
tests.invalid_deep_source = caught;

tests.all_passed = all(structfun(@(x)logical(x),tests));
if ~tests.all_passed
    error('eegsl:Tests:SyntheticValidationFailure','Synthetic validation test failed.');
end
end

function key = stage_key(stages,name)
idx = find(cellfun(@(x)strcmp(x.stage,name),stages),1,'first');
if isempty(idx)
    error('eegsl:Tests:SyntheticValidationStageKey','Missing stage %s in cache summary.',name);
end
key = stages{idx}.key;
end
