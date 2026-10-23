# Synthetic validation workflow

The toolbox provides a dependency-light synthetic smoke-test pipeline:

```matlab
addpath(genpath('matlab'));
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = fullfile(tempdir,'eegsl_cache');
cfg.noise.route = 'diagonal';
cfg.inverse.lambda = 0.05;
cfg.synthetic.seed = 42;
result = eegsl.run_synthetic_validation(cfg);
```

Or run the one-command smoke helper:

```matlab
addpath(genpath('matlab'));
addpath('tests');
result = run_synthetic_validation_smoke();
```

`eegsl.run_synthetic_validation` runs deterministic stages for:

1. synthetic source/electrode geometry;
2. analytic lead field creation;
3. source simulation and sensor projection with controlled noise;
4. covariance estimation with `eegsl.noise.estimate_noise_cov`;
5. wMNE inverse-operator build;
6. inverse application;
7. optional normalization (opt-in via `cfg.synthetic.normalization.enabled` and `cfg.normalization.enabled`);
8. cache-backed artifact reuse per stage.

The returned `result` includes source/sensor artifacts, dimensions, stage provenance, cache keys with hit/miss counts, and validation metrics (sensor reconstruction error, active-source correlation, localization error, deep-source localization diagnostics).

## What this validates

- Deterministic and cache-reusable pipeline orchestration.
- Dependency-free synthetic forward/inverse/noise integration path.
- Basic numerical sanity for source estimation and depth-sensitive behavior.

## What this does not validate

- FEM assembly or FEM mesh correctness.
- MRI co-registration quality.
- Scientific claims about subcortical-resolution accuracy.
