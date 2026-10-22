# Architecture

The toolbox is organized as a MATLAB package rooted at `matlab/+eegsl`.

- `+common`: configuration, deterministic content hashes, coordinate checks, cache/provenance, and progress logging.
- `+source`: source-space construction. The default is a volumetric grid masked by permitted gray matter; labels retain structure, tier, and provenance.
- `+forward`: engine-agnostic head-model, sensor-linking, and lead-field seams. FieldTrip/SimBio/DUNEuro adapters are explicit integration points; no FEM is reimplemented here.
- `+noise`: paradigm-aware covariance estimation, including the dependency-free uniform-null geometry and sigma-max search.
- `+inverse`: frozen build/apply interface. wMNE is implemented as a transparent baseline; other methods fail clearly until their numerical validation is added.
- `+normalization`: optional frozen Michel-Brunet-style post-normalization.
- `+petra`: PETRA fallback/provenance seam. External registration and segmentation are not silently emulated.

All precompute functions return provenance metadata. Apply functions are deliberately pure projections or elementwise transforms and do not log, estimate covariance, or select parameters.

The package is designed to run without FieldTrip or external command-line tools for unit testing. Adapters detect missing dependencies and report actionable errors.
