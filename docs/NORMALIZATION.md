# Normalization module

Normalization is an opt-in post-stage with its own frozen build/apply lifecycle:

```matlab
cfg.normalization.enabled = true;
[norm_op, info] = eegsl.normalization.build_normalization(source_background, cfg);
normalized = eegsl.normalization.apply_normalization(norm_op, source_estimate);
```

For free orientation, the background is expected as `3*Npoints x time`, and the module computes per-point squared vector norms before applying the configurable power transform. Scalar source estimates can be handled with `cfg.normalization.orientation = 'scalar'`.

The build stage uses repeated random sub-sampling from a private `RandStream`, a
lower-half histogram mode estimate, and
`mad_scale * median(abs(below - mu))` for its left-side MAD scale estimate,
centered on the estimated mode `mu`. `normalization.mad_scale` defaults to 1
(unscaled MAD); whether to use the Gaussian consistency constant 1.4826 remains
open. Set `normalization.seed` to freeze the subsample stream; it falls back to
`cfg.seed`, then 0. The selected seed is recorded in the operator and its ID.

The stable-state check is a heuristic: it reports points whose transformed
activity exceeds their estimated background by `stable_state_z` for more than
`stable_state_fraction_warning` of the window. It can detect activity elevated
above a quiet background, but cannot detect a point whose background estimate
was itself captured by sustained activity. Per-point stable fractions and
indices are stored in provenance.

The apply stage only performs the frozen elementwise transform:

```text
spN = spchi^exponent
spZ+ = max((spN - mu) / sigma + shift, 0) / scale
```

It emits no progress and does not re-estimate any factors. For struct inputs it
writes the result back to the sample field (`trial`, `avg`, or `data`) supplied by
the caller, applying the same frozen factors independently to every trial.
Normalization remains separate from inverse scalar reduction and is never
invoked by `apply_inverse`.
