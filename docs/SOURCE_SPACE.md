# Source-space module

`eegsl.source.build_source_space` creates a dependency-free, FieldTrip-compatible volumetric `sourcemodel` from a 3-D gray-matter mask. The default mode is whole-brain/free orientation; set `cfg.source.mode = 'cortical'` for a cortical-only/surface-normal contract.

```matlab
addpath(genpath('matlab'));
anatomy.mask = gmMask;
anatomy.transform = voxelToWorld;
anatomy.unit = 'mm';
anatomy.labels = structureLabelVolume;
anatomy.label_map = struct( ...
    'value',{1,2}, 'name',{'thalamus','cortex'}, ...
    'tier',{'tier1','tier1'}, 'provenance',{'freesurfer','charm'});
elec.chanpos = electrodePositions;

cfg = eegsl.default_config();
cfg.paradigm = 'resting';
[sourcemodel, info] = eegsl.source.build_source_space(anatomy, elec, cfg);
```

The electrode-density heuristic targets `clamp(round(12*nchan), min_points, max_points)` by default. This is a provisional engineering heuristic, not a claim of spatial resolution; it is deliberately configurable and should be revised using montage validation.

The module preserves per-point structure labels and records tier/provenance. Atlas-derived approximate targets must be represented as such and must not be reported as verified STN or GPi/GPe segmentation.
