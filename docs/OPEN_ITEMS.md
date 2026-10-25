# Open implementation items

The following remain intentionally configurable or adapter-only rather than silently receiving invented scientific defaults:

- Exact FieldTrip API fields for the installed release.
- Verify installed `ft_prepare_vol_sens`, `ft_prepare_leadfield`, `ft_compute_leadfield`, and SimBio transfer-matrix behavior before changing adapter call signatures.
- FreeSurfer command names and DTI-joint thalamic module availability.
- Lead-DBS atlas selection, warp method, licensing, and QC thresholds.
- PETRA registration backend (SPM versus ANTs), registration QC thresholds, N4 availability, and conductivity values.
- SimBio/DUNEuro anisotropic tensor conductivity plumbing.
- Concrete grid-density heuristic after real montage data are available.
- Primary-source numerical validation of eLORETA, sLORETA, and LCMV against FieldTrip.
- LCMV data-covariance versus noise-covariance policy when uniform-null noise is selected.
- Regularization defaults and representative-window policy.
- Causal real-time filter design, delay characterization, and online quality-monitoring thresholds.
- Uniform-null scaling for fixed-orientation lead fields; confirm against Moiseev 2025.
- Whether the source-grid symmetry plane should use an optimal sagittal-plane estimate instead of the mask centroid.
- Validate the provisional electrode-density heuristic; its clamp yields about 3000 points for montages up to 250 channels.
- Confirm the proposed cortical-only representation: volumetric mask with free orientation or surface mesh with surface-normal orientation.
- Confirm whether normalization MAD should use the Gaussian consistency factor 1.4826, as opposed to the provisional unscaled-MAD default.
- Validate the stable-state heuristic threshold and method against representative source windows.
- Unify preprocessing under `cfg.preprocessing` and derive its mode from `cfg.execution.mode` (tracked as future N10 work).

The implementation must expose these as configuration or explicit adapter seams. It must not claim STN-specific or GPi-versus-GPe resolution from standard T1 imaging.
