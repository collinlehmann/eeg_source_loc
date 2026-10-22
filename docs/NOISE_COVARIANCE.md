# Noise covariance module

The entry point is:

```matlab
[N, ncov_info] = eegsl.noise.estimate_noise_cov(cfg, data, leadfield, headmodel);
```

`cfg.paradigm` is mandatory. The route defaults are:

- `task` -> `baseline`, requiring `cfg.baseline = [tmin tmax]`;
- `resting` -> `uniform_null`, requiring a lead field.

The resting-state `baseline` route errors. `diagonal` and `emptyroom` routes emit explicit warnings because they do not represent a uniform source-level baseline for spontaneous activity.

The uniform-null route accumulates

```text
G = sum_i H_i * H_i'
N = Lambda + (sigma^2 / 3) * G
```

and selects the largest admissible `sigma` for which `R - N` remains positive semidefinite. A supplied reference projector is applied to both data covariance and lead-field blocks before the geometry and PSD checks. The complete route, reference, regularization, sigma, geometry, and identity metadata are returned in `ncov_info`.

The implementation is dependency-free and accepts numeric matrices, FieldTrip-like `trial`/`time` structs, `avg` structs, and covariance-bearing structs. Exact FieldTrip reference metadata and the final LCMV `R` versus `N` policy remain open items documented in `docs/OPEN_ITEMS.md`.
