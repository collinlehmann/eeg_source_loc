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

# `eegsl.validate_synthetic_e2e`

The newer public entrypoint is `eegsl.validate_synthetic_e2e(cfg)`. It runs a
cache-aware, deterministic pipeline built from the `eegsl.synthetic` package
and returns `result.synthetic`, `result.inverse`, `result.normalization`
(only when `cfg.normalization.enabled` is true), `result.metrics`,
`result.cache` and `result.provenance`. `eegsl.run_synthetic_validation`
is unchanged.

Stages (each cached under artifact kind `synthetic`; a hit loads the artifact,
a miss computes and saves it with stage name, seed, dimensions and config
hash in the metadata):

1. source space (includes a deep source when `include_deep_source` is true);
2. deterministic dipole-like leadfield;
3. deterministic source time series;
4. forward projection plus white noise (`snr_db`, default 20 dB);
5. `eegsl.noise.estimate_noise_cov` (default route `diagonal`);
6. wMNE inverse operator (`eegsl.inverse.build_inverse`);
7. inverse application (`eegsl.inverse.apply_inverse`);
8. optional normalization (`eegsl.normalization.*`, opt-in);
9. metrics, provenance and cache summary.

## Config (`cfg.synthetic`)

`enabled`, `seed`, `n_channels`, `n_sources`, `n_samples` (alias of `n_time`;
if both are set they must agree), `sample_rate_hz`, `snr_db`,
`orientation_mode` (`'free'` = 3 components/source, `'scalar'` = 1),
`include_deep_source`, `noise_model` (`'white'`). Internally matrices are
channels/components-by-samples; `sensor_orientation` / `source_orientation`
only affect the returned `result.synthetic.sensor_data` / `source_data`.
Errors use `eegsl:Config:Synthetic*` (config) and `eegsl:Synthetic:*`
(shape mismatches).

## Example

```matlab
addpath(genpath('matlab'));
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = fullfile(tempdir,'eegsl_cache');
cfg.noise.route = 'diagonal';
cfg.inverse.lambda = 0.05;
cfg.synthetic.enabled = true;
cfg.synthetic.seed = 42;
cfg.synthetic.n_channels = 16;
cfg.synthetic.n_sources = 10;
cfg.synthetic.n_samples = 300;
cfg.synthetic.deep_source_index = 6;

cold = eegsl.validate_synthetic_e2e(cfg);   % all stages miss
warm = eegsl.validate_synthetic_e2e(cfg);   % all stages hit
disp(warm.metrics.sensor_rmse)              % also: sensor_relative_frobenius,
                                            % source_correlation_mean, source_r2,
                                            % localization_error, top3_hit
disp(warm.cache.by_stage)                   % 'hit'/'miss' per stage
```

Metrics are deterministic; repeated runs agree to about 1e-10 and the tests
use an absolute tolerance of 1e-9. Metric values are not accuracy benchmarks.
The noise covariance is estimated from the noisy data itself (diagonal),
which is a simplification.

Tests: `test_synthetic_e2e`, `test_synthetic_determinism`,
`test_synthetic_malformed`, `test_synthetic_no_fieldtrip` (helper:
`synthetic_e2e_cfg`).
