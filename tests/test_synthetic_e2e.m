function tests = test_synthetic_e2e()
%TEST_SYNTHETIC_E2E Cold/warm cache end-to-end test for validate_synthetic_e2e.
% Numeric tolerance: runs are deterministic; 1e-9 absolute is generous.
tol = 1e-9;
[cfg, root] = synthetic_e2e_cfg(7);
cleanup = onCleanup(@()rmdir(root,'s')); %#ok<NASGU>

r1 = eegsl.validate_synthetic_e2e(cfg);
r2 = eegsl.validate_synthetic_e2e(cfg);

tests.cold_all_miss = r1.cache.hits == 0 && r1.cache.misses == 7;
tests.warm_all_hit = r2.cache.hits == 7 && r2.cache.misses == 0;
tests.warm_by_stage = all(structfun(@(x)strcmp(x,'hit'),r2.cache.by_stage));
tests.sections = all(isfield(r1,{'synthetic','inverse','metrics','cache','provenance'}));
tests.no_normalization_by_default = ~isfield(r1,'normalization');
tests.estimate_consistent = norm(r1.inverse.estimate - r2.inverse.estimate,'fro') < tol;
tests.sensor_consistent = norm(r1.synthetic.sensor_noisy - r2.synthetic.sensor_noisy,'fro') < tol;
tests.metrics_consistent = abs(r1.metrics.sensor_rmse - r2.metrics.sensor_rmse) < tol && ...
    abs(r1.metrics.source_correlation_mean - r2.metrics.source_correlation_mean) < tol;
tests.metrics_present = all(isfield(r1.metrics,{'sensor_rmse','sensor_relative_frobenius', ...
    'source_correlation_mean','source_r2','localization_error','top3_hit','cache'}));
tests.metrics_finite = isfinite(r1.metrics.sensor_rmse) && isfinite(r1.metrics.localization_error);
tests.stage_metadata = isfield(r2.cache.stages{1}.metadata,'seed') && ...
    isfield(r2.cache.stages{1}.metadata,'stage') && isfield(r2.cache.stages{1}.metadata,'config_hash');
tests.deep_source = ~isempty(r1.synthetic.source_space.deep_source_index) && ...
    ismember(6,r1.synthetic.active_sources);
tests.leadfield_labels = isequal(r1.synthetic.leadfield.label, ...
    arrayfun(@(k)sprintf('E%d',k),1:cfg.synthetic.n_channels,'UniformOutput',false)');

cfg.normalization.enabled = true;
r3 = eegsl.validate_synthetic_e2e(cfg);
tests.normalization_opt_in = isfield(r3,'normalization') && r3.cache.misses == 1 && r3.cache.hits == 7;

cfg.synthetic.orientation_mode = 'scalar';
cfg.synthetic.sensor_orientation = 'samples_by_channels';
r4 = eegsl.validate_synthetic_e2e(cfg);
tests.scalar_dims = size(r4.inverse.estimate,1) == cfg.synthetic.n_sources && ...
    isequal(size(r4.synthetic.sensor_data),[cfg.synthetic.n_samples cfg.synthetic.n_channels]) && ...
    isequal(size(r4.synthetic.source_data),[cfg.synthetic.n_samples cfg.synthetic.n_sources]);

bad = cfg; bad.synthetic.active_sources = cfg.synthetic.n_sources+1;
tests.invalid_active_sources = error_id(@()eegsl.validate_config(bad), ...
    'eegsl:Config:SyntheticActiveSourceRange');
bad = cfg; bad.synthetic.deep_source_index = cfg.synthetic.n_sources+1;
tests.invalid_deep_source = error_id(@()eegsl.validate_config(bad), ...
    'eegsl:Config:SyntheticDeepSourceRange');

corruptCfg = cfg;
corruptCfg.synthetic.seed = 44;
rCorrupt = eegsl.validate_synthetic_e2e(corruptCfg);
stageIdx = find(cellfun(@(x)strcmp(x.stage,'sensor_data'),rCorrupt.cache.stages),1);
sensorKey = rCorrupt.cache.stages{stageIdx}.key;
[badSensor,metadata] = eegsl.common.load_artifact(corruptCfg,'synthetic',sensorKey);
badSensor.noisy = badSensor.noisy.';
corruptCfg.cache.overwrite = true;
eegsl.common.save_artifact(corruptCfg,'synthetic',sensorKey,badSensor,metadata, ...
    'synthetic.sensor_data');
caught = false;
try
    eegsl.validate_synthetic_e2e(corruptCfg);
catch err
    caught = strcmp(err.identifier,'eegsl:Synthetic:DimensionMismatch');
end
tests.corrupted_sensor_artifact = caught;

avgCfg = cfg;
avgCfg.noise.route = 'uniform_null';
avgCfg.reference.projector = eye(cfg.synthetic.n_channels)- ...
    ones(cfg.synthetic.n_channels)/cfg.synthetic.n_channels;
avgResult = eegsl.validate_synthetic_e2e(avgCfg);
N = avgResult.inverse.noise_covariance;
tests.uniform_null_avgref = isfinite(avgResult.metrics.sensor_rmse) && ...
    isfinite(avgResult.metrics.localization_error) && ...
    norm(N*ones(cfg.synthetic.n_channels,1)) <= 1e-9*norm(N);

assert_test_checks(tests,'test_synthetic_e2e');
tests.all_passed = true;
end

function caught = error_id(fcn,id)
caught = false;
try, fcn(); catch err, caught = strcmp(err.identifier,id); end
end
