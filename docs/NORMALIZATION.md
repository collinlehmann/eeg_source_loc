# Normalization module

Normalization is an opt-in post-stage with its own frozen build/apply lifecycle:

```matlab
cfg.normalization.enabled = true;
[norm_op, info] = eegsl.normalization.build_normalization(source_background, cfg);
normalized = eegsl.normalization.apply_normalization(norm_op, source_estimate);
```

For free orientation, the background is expected as `3*Npoints x time`, and the module computes per-point squared vector norms before applying the configurable power transform. Scalar source estimates can be handled with `cfg.normalization.orientation = 'scalar'`.

The build stage uses repeated random sub-sampling, a lower-half histogram mode estimate, and a left-side MAD scale estimate. The resulting `mu` and `sigma` are frozen in the operator. Short windows and possible stable-state domination produce warnings and are recorded in provenance.

The apply stage only performs the frozen elementwise transform:

```text
spN = spchi^exponent
spZ+ = max((spN - mu) / sigma + shift, 0) / scale
```

It emits no progress and does not re-estimate any factors. Normalization remains separate from inverse scalar reduction and is never invoked by `apply_inverse`.
