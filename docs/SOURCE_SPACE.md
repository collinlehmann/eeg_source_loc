# Source-space module

`eegsl.source.build_source_space` samples a regular lattice in world coordinates
from an anatomical mask. Required inputs are a 3-D logical `anatomy.mask`, a 4x4
`anatomy.transform`, its explicit `anatomy.transform_convention` (`fieldtrip` for
1-based voxel indices or `nifti` for 0-based indices), and `anatomy.unit` (`mm`,
`cm`, or `m`). The optional coordinate-system name is required when symmetry is
enabled and must identify an x axis oriented left-right.

```matlab
anatomy.mask = gmMask;
anatomy.transform = voxelToWorld;
anatomy.transform_convention = 'fieldtrip';
anatomy.unit = 'mm';
anatomy.coordsys = 'ras';
anatomy.labels = structureLabelVolume;
anatomy.label_map = struct( ...
    'value',{1,2}, 'name',{'thalamus','cortex'}, ...
    'tier',{'tier1','tier1'}, 'provenance',{'freesurfer','charm'});
```

The transform is converted internally to FieldTrip's 1-based convention before
mask sampling. A configured scalar `cfg.source.spacing_mm` is converted into the
anatomy's units; anisotropic spacing is not supported. If spacing is omitted, it
is estimated from mask volume and the electrode-density target, then adjusted for
up to ten iterations. The final count and number of iterations are returned in
`info`.

When `cfg.source.symmetry` is enabled, the x lattice is centered on
`cfg.source.midsagittal_x`, either a world x coordinate or the default
`'mask_centroid'`. The lattice itself is symmetric. In the default
`cfg.source.symmetry_mode = 'lattice'`, the mask determines inside points and
anatomical asymmetry is retained. `'enforce'` additionally intersects inside
points with their mirrored points. `info.unpaired_points` reports unpaired inside
indices. With symmetry disabled, the x axis uses the same origin alignment as y
and z.

Optional neighbor continuity operates on the source lattice rather than the
voxel grid, applying the configured 26-neighbor threshold for the configured
number of passes. `sourcemodel.pos` contains every lattice point and the logical
`inside` vector selects valid points. `dim` spans the complete lattice, and
`transform` maps 1-based lattice indices to `pos`, as required by FieldTrip.
Outside points receive `'outside'` label, tier, and provenance values; FieldTrip
derives the outside set from `inside`.

The electrode-density heuristic targets
`clamp(round(12*nchan), min_points, max_points)`. It is provisional, not a claim
of spatial resolution; for montages up to 250 channels the default clamp gives
about 3000 points. The appropriate target should be revised using montage
validation. Whether the mask centroid should be replaced by an optimal
mid-sagittal plane estimator remains open. Atlas-derived approximate targets
must not be reported as verified STN or GPi/GPe segmentation.
