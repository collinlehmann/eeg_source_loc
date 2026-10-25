# Synthetic validation workflow

Use `eegsl.validate_synthetic_e2e(cfg)` for deterministic, cache-aware
dependency-free integration validation:

```matlab
addpath(genpath('matlab'));
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg.cache.root = fullfile(tempdir,'eegsl_cache');
cfg.noise.route = 'diagonal';
cfg.inverse.lambda = 0.05;
cfg.synthetic.enabled = true;
cfg.synthetic.seed = 42;
result = eegsl.validate_synthetic_e2e(cfg);
```

The pipeline runs synthetic source-space generation, lead-field generation,
source simulation, sensor projection and noise, noise-covariance estimation,
wMNE construction/application, and optional normalization. Its stage-scoped
cache keys allow unrelated config changes to reuse artifacts.

`eegsl.run_synthetic_validation(cfg)` remains temporarily as a deprecated alias;
it warns with `eegsl:Deprecated:RunSyntheticValidation` and calls
`eegsl.validate_synthetic_e2e`.

## What this validates

- Deterministic stage orchestration and cache reuse.
- Dependency-free noise, inverse, and normalization plumbing.
- Output dimensions and orientation conversions.
- Reference-projector handling, including an average-reference uniform-null case.

## Limitations

The same synthetic lead field generates and inverts the data (an **inverse
crime**). The resulting metrics are plumbing checks, not accuracy benchmarks.
The synthetic lead field is not a physical FEM model, and the pipeline does not
validate MRI co-registration, source localization accuracy, or clinical
resolution. Accuracy validation without the inverse crime is tracked separately
as future work.

The free-orientation lead field retains a shared distance-dependent gain falloff.
Labels are emitted as `E1` through `En` so channel-order checks exercise the
production inverse interface.
