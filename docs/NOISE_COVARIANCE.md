# Noise covariance module

The canonical configuration fields are:

```matlab
cfg.noise.route = 'baseline';
cfg.noise.baseline = [tmin tmax];
cfg.noise.emptyroom = emptyroomDataOrCovariance;
```

The estimator accepts the older top-level `cfg.baseline` and `cfg.emptyroom` fields temporarily, migrates them into `cfg.noise`, and emits deprecation warnings. New code should use only the nested fields.

For `uniform_null`, the admissible covariance scale is computed in the retained
non-null sensor subspace. By default `cfg.noise.sigma_method = 'closed_form'` uses
the largest generalized eigenvalue of the geometry term relative to
`R - Lambda`; `'bisection'` is available as a numerical cross-check. Both methods
use `cfg.noise.tol` as a **relative** tolerance scaled by the largest absolute
eigenvalue of the data covariance, so results do not depend on whether data are
expressed in volts or microvolts.

The baseline route requires per-sample time vectors to select the configured
interval; numeric arrays without time information are rejected rather than
silently treated as a baseline. A rank-deficient data covariance without an
explicit reference projector emits `eegsl:Noise:RankDeficientNoProjector`.
Regularization after `uniform_null` is permitted but warns that it may invalidate
the PSD bound; the post-regularization minimum eigenvalue ratio is recorded.
