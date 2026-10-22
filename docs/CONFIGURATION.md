# Configuration contracts

`eegsl.default_config` is the canonical root schema. Call `eegsl.validate_config` before passing configuration to a pipeline stage.

```matlab
cfg = eegsl.default_config();
cfg.paradigm = 'resting';
cfg = eegsl.validate_config(cfg);
```

The validator normalizes enum strings, validates scalar/matrix/window types, checks cross-field invariants, and preserves unresolved scientific decisions as explicit fields.

Important contracts:

- `cfg.paradigm` is required and must be `task` or `resting`.
- Resting data cannot use the baseline covariance route.
- `noise.baseline` is required and ordered when the baseline route is selected.
- Source-point bounds must be positive and ordered.
- Real-time execution mode must agree with `execution.realtime`.
- Interactive-offline mode cannot be headless.
- Reference projectors must be finite square matrices.
- Cache read-only and overwrite modes are mutually exclusive.
- Normalization remains opt-in.

Module-local validators may impose additional adapter constraints. They should consume the canonical fields rather than silently redefining root semantics.
