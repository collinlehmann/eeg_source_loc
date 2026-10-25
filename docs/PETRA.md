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
- refinement is fail-closed: a `qc_callback` and non-empty Dice/surface-distance thresholds are mandatory;
- the module computes the QC pass decision from returned metrics and ignores callback-provided `pass` values;
- failed QC or adapter errors return unchanged charm labels and record the reason (or error when fallback is disabled);
- fallback and refined outputs carry distinct provenance.

The callbacks are deliberate dependency seams. A production registration callback should implement rigid PETRA-to-charm-conformed-T1 registration using the selected SPM or ANTs backend. A production segmentation callback should perform bias correction, erosion-constrained intensity classification, topology cleanup, and return compact/cancellous masks that fully partition the charm skull label. A QC callback returns numeric scalar `dice` and `surface_distance95` metrics; the module compares those with `cfg.petra.qc.dice_min` and `surface_distance95_max`.

All options belong in `cfg.petra`. The legacy top-level PETRA config is temporarily accepted with a deprecation warning. Label IDs are required and must be distinct; the module does not infer IDs from the current label maximum.

No external tool is invoked by this module or its tests. This prevents tests from pretending that SPM, ANTs, N4, or PETRA data are available.
