# Disk-backed cache manager

The cache manager uses only MATLAB filesystem APIs (`fullfile`, `mkdir`, `movefile`, `isfile`, `isfolder`, `dir`, `delete`, and `rmdir`) and is intended to work on Windows and macOS.

Content keys use SHA-256 over MATLAB's `getByteStreamFromArray` serialization and
require the JVM. This serialization function is undocumented and may change between
MATLAB releases; a release change can therefore cause cache misses, but not incorrect
cache hits. `cache_info.matlab_version` is recorded with each artifact.

The hardened cache provides:

- atomic same-directory writes;
- schema, kind, and key validation;
- configuration fingerprints attached to metadata;
- metadata integrity hashes;
- directory-based locks with timeout and stale-lock cleanup;
- stale temporary-file cleanup;
- read-only, overwrite, and disabled-cache enforcement;
- cache-manifest inspection;
- explicit errors for missing, corrupt, incompatible, and mismatched artifacts.

Cache location and concurrency settings are excluded from the configuration fingerprint, so moving the cache or changing lock policy does not invalidate scientific artifacts. Stage-aware artifacts fingerprint only the settings consumed by that stage, and their keys include that fingerprint. A relevant setting change therefore creates a cache miss; a configuration mismatch on load indicates tampering or corruption. Legacy artifacts saved without a stage continue to use the full configuration hash.

The stage fingerprint scope is:

| Stage | Configuration fields |
|---|---|
| `source_space` | `schema_version`, `source` |
| `stiffness` | `forward.engine`, `forward.fieldtrip.headmodel` |
| `transfer` | `forward.engine`, `forward.fieldtrip.vol_sens` |
| `leadfield` | `forward.engine`, `forward.orientation`, `forward.fieldtrip.leadfield` |
| `noise_covariance` | `paradigm`, `noise`, `reference` |
| `inverse_operator` | `inverse`, `reference` |
| `normalization` | `normalization` excluding `enabled` and `seed` |
| `petra` | `petra` |
| `synthetic.source_space`, `synthetic.leadfield`, `synthetic.sources`, `synthetic.sensor_data`, `synthetic.source_estimate` | synthetic settings excluding orientation/output, normalization, cache-prefix, and enabled toggles |
| `synthetic.noise_covariance` | synthetic core, `paradigm`, `noise`, `reference` |
| `synthetic.inverse_operator` | synthetic core, `inverse`, `reference` |
| `synthetic.normalization` | `normalization` excluding `enabled` and `seed` |
