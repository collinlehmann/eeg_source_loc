# Inverse-operator module

The stable interface is:

```matlab
[operator, info] = eegsl.inverse.build_inverse(leadfield, noise_cov, cfg);
source = eegsl.inverse.apply_inverse(operator, data);
```

`apply_inverse` is intentionally a silent matrix projection. It does not estimate covariance, select regularization, or perform normalization.

The current dependency-free numerical implementation is weighted minimum norm (`wmne`). It computes one Frobenius-norm depth weight per source location and repeats that weight across the location's orientation block, making the source norm invariant to rotations of the local coordinate frame. Numeric lead fields must declare their orientation so the block layout is unambiguous. An explicit `cfg.inverse.lambda` is recommended for reproducible experiments; when omitted, a conservative scale-derived placeholder is recorded in the operator metadata.

The registry already accepts `eloreta`, `sloreta`, and `lcmv`, but those methods currently fail explicitly with `eegsl:Inverse:NotImplemented` until their primary-source mathematics and FieldTrip numerical validation are added. This is deliberate: the toolbox must not present unvalidated inverse mathematics as production-ready.

Free-orientation estimates remain component-valued. `operator.recommended_reduction`
records the method-specific suggestion (`norm` for the implemented wMNE family,
`dominant` for LCMV); a non-empty `cfg.inverse.reduction` overrides it.
`operator.label` stores the lead-field channel labels for apply-time order checks.
`apply_inverse` never reduces source components. Use
`eegsl.inverse.reduce_source` as a separate reduction utility; `dominant` currently
errors until a frozen per-location orientation can be computed at build time.
Normalization remains a separate downstream module and is not part of `apply_inverse`.
