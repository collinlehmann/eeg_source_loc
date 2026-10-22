# Open implementation items

The following remain intentionally configurable or adapter-only rather than silently receiving invented scientific defaults:

- Exact FieldTrip API fields for the installed release.
- FreeSurfer command names and DTI-joint thalamic module availability.
- Lead-DBS atlas selection, warp method, licensing, and QC thresholds.
- PETRA registration backend (SPM versus ANTs), registration QC thresholds, N4 availability, and conductivity values.
- SimBio/DUNEuro anisotropic tensor conductivity plumbing.
- Concrete grid-density heuristic after real montage data are available.
- Primary-source numerical validation of eLORETA, sLORETA, and LCMV against FieldTrip.
- LCMV data-covariance versus noise-covariance policy when uniform-null noise is selected.
- Regularization defaults and representative-window policy.
- Causal real-time filter design, delay characterization, and online quality-monitoring thresholds.

The implementation must expose these as configuration or explicit adapter seams. It must not claim STN-specific or GPi-versus-GPe resolution from standard T1 imaging.
