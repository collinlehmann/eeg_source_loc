# Noise covariance module

The canonical configuration fields are:

```matlab
cfg.noise.route = 'baseline';
cfg.noise.baseline = [tmin tmax];
cfg.noise.emptyroom = emptyroomDataOrCovariance;
```

The estimator accepts the older top-level `cfg.baseline` and `cfg.emptyroom` fields temporarily, migrates them into `cfg.noise`, and emits deprecation warnings. New code should use only the nested fields.
