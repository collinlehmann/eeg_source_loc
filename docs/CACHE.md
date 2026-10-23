# Disk-backed cache manager

The cache manager is platform-independent and uses MATLAB filesystem APIs only:

- `fullfile` for paths;
- `isfile`, `isfolder`, `mkdir`, `dir`, and `delete` for filesystem operations;
- same-directory temporary files plus `movefile(...,'f')` for atomic commits;
- MAT-file serialization, avoiding shell commands and OS-specific path syntax.

Usage:

```matlab
cfg = eegsl.default_config();
cfg.cache.root = fullfile(tempdir,'eegsl-cache');
cfg.cache.overwrite = true;

key = eegsl.common.cache_key('leadfield',leadfield_id,source_space_id);
eegsl.common.save_artifact(cfg,'leadfield',key,leadfield,provenance);

if eegsl.common.has_artifact(cfg,'leadfield',key)
    [leadfield, provenance] = eegsl.common.load_artifact(cfg,'leadfield',key);
end
```

Each artifact stores its kind, key, schema version, creation timestamp, MATLAB version, and artifact class. The loader rejects missing fields, mismatched keys/kinds, and schema-version mismatches.

Cache roots should be configured with `fullfile` rather than hard-coded separators. The implementation does not invoke `mkdir`, `rm`, `cp`, `mv`, or other shell commands, so it works on Windows and macOS without relying on a particular shell.
