# Preprocessing module

The orchestration entry point is:

```matlab
[clean, info] = eegsl.preprocessing.preprocess(data, cfg);
```

The configuration distinguishes:

- `interactive-offline`
- `automated-offline`
- `realtime`

The implementation enforces key spec constraints:

- real-time filtering must be causal;
- real-time epoch rejection is prohibited;
- interactive offline artifact removal cannot silently use an unconfirmed automatic ICA policy;
- artifact removal, filter design, downsampling, interpolation, bad-channel detection, and spatial filtering are explicit callbacks;
- quality monitoring always runs and exposes a control-gating signal in real-time mode.

The callback boundary is intentional. It allows FieldTrip-based filtering, ICA, regression, interpolation, and the Cartool-style spatial filter to be integrated without inventing toolbox-specific behavior in the orchestration layer. Filter and artifact configuration is retained in provenance, including whether the path was causal.

The default quality monitor performs a finite-sample check and reports channel/global RMS. Production real-time deployments should provide a callback that adds impedance/drift, artifact-rate, and frozen-ICA stationarity metrics.
