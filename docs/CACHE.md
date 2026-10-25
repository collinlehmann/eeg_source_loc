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

Cache location and concurrency settings are excluded from the configuration fingerprint, so moving the cache or changing lock policy does not invalidate scientific artifacts. Scientific configuration changes do invalidate cache loads when the artifact metadata carries a configuration hash.
