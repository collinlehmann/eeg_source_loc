# PETRA refinement module

The PETRA module now provides a safe integration seam:

```matlab
[labels, petra_info] = eegsl.petra.refine_skull_with_petra(cfg, charm_out, petra_vol);
```

The module enforces the project rules:

- missing PETRA falls back to unchanged charm labels;
- PETRA is never silently passed into charm;
- PETRA masks may overwrite only charm skull voxels;
- registration and segmentation require explicit callbacks;
- quantitative QC can be supplied through `qc_callback`;
- failed QC or adapter errors fall back and record the reason;
- fallback and refined outputs carry distinct provenance.

The callbacks are deliberate dependency seams. A production registration callback should implement rigid PETRA-to-charm-conformed-T1 registration using the selected SPM or ANTs backend. A production segmentation callback should perform bias correction, erosion-constrained intensity classification, topology cleanup, and return compact/cancellous masks. A QC callback should compute the required Dice and symmetric surface-distance metrics and set `qc.pass` only when both gates pass.

No external tool is invoked by this module or its tests. This prevents tests from pretending that SPM, ANTs, N4, or PETRA data are available.
