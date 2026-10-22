# Inverse-operator module

The stable interface is:

```matlab
[operator, info] = eegsl.inverse.build_inverse(leadfield, noise_cov, cfg);
source = eegsl.inverse.apply_inverse(operator, data);
```

`apply_inverse` is intentionally a silent matrix projection. It does not estimate covariance, select regularization, or perform normalization.

The current dependency-free numerical implementation is weighted minimum norm (`wmne`). It uses the lead-field column norms for configurable depth weighting and a frozen covariance inverse. An explicit `cfg.inverse.lambda` is recommended for reproducible experiments; when omitted, a conservative scale-derived placeholder is recorded in the operator metadata.

The registry already accepts `eloreta`, `sloreta`, and `lcmv`, but those methods currently fail explicitly with `eegsl:Inverse:NotImplemented` until their primary-source mathematics and FieldTrip numerical validation are added. This is deliberate: the toolbox must not present unvalidated inverse mathematics as production-ready.

Free-orientation estimates remain component-valued. Use `eegsl.inverse.reduce_source` as a separate reduction utility. Normalization will be implemented as its own downstream module and is not part of `apply_inverse`.
