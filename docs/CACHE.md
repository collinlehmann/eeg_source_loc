# Disk-backed cache manager

The cache manager uses only MATLAB filesystem APIs (`fullfile`, `mkdir`, `movefile`, `isfile`, `isfolder`, `dir`, `delete`, and `rmdir`) and is intended to work on Windows and macOS.

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
