function result = run_synthetic_validation_smoke()
%RUN_SYNTHETIC_VALIDATION_SMOKE One-command synthetic E2E smoke runner.
%
% Usage:
%   addpath(genpath('matlab'));
%   addpath('tests');
%   result = run_synthetic_validation_smoke();

cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = fullfile(tempdir,'eegsl_cache_smoke');
cfg.noise.route = 'diagonal';
cfg.inverse.lambda = 0.05;
cfg.synthetic.seed = 42;

result = eegsl.validate_synthetic_e2e(cfg);
end
