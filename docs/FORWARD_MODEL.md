# Forward-model module

The forward module keeps the project boundary explicit:

```matlab
headmodel = eegsl.forward.build_headmodel(mesh, conductivity, cfg);
[linked, elecProjected] = eegsl.forward.link_sensors(headmodel, elec, cfg);
leadfield = eegsl.forward.build_leadfield(linked, elecProjected, sourcemodel, cfg);
```

The default engine is SimBio through FieldTrip. DUNEuro is a swappable adapter. The analytic engine is an explicit fast-turnaround seam and requires either a supplied lead field/head model or a custom callback; it does not silently invent a solver.

The cache decomposition is derived from inputs before computation; it never hashes
the stiffness or transfer outputs:

1. stiffness: stage fingerprint + mesh + conductivity + engine;
2. transfer: stiffness key + transfer-stage fingerprint + electrode geometry;
3. lead field: transfer key + leadfield-stage fingerprint + source-space ID + orientation.

Populate `cfg.forward.cache_keys` with the result of
`eegsl.forward.forward_cache_keys(mesh, conductivity, elec, sourcemodel, cfg)`
before invoking the adapters to attach those stable identifiers to their outputs.

`link_sensors` brackets the transfer stage with wall-clock timing because it is the dominant FEM cost. No custom FEM assembly and no per-source FEM solves are implemented.

FieldTrip is required for the SimBio and DUNEuro paths. Missing dependencies produce explicit errors. The adapter tests use only the analytic path and synthetic structs.

FEM forward calculations always request free orientation from FieldTrip
(`fixedori='no'`). For `surface-normal`, the adapter requires source normals and
projects each free-orientation block as `H_i*n_i'`; FieldTrip's fixed-orientation
maximum-power selection is not used. An analytic adapter that returns already
projected one-column blocks must explicitly set
`cfg.forward.analytic.prenormal = true`.

FEM conductivity may be supplied as tissue-name/value pairs and is reordered to
`mesh.tissuelabel`; numeric vectors are accepted with an order-assumed warning.
The FieldTrip call signatures, accepted vol-sens options, version reporting, and
whether `ft_prepare_leadfield` recomputes a linked transfer matrix still require
verification against an installed FieldTrip source tree. The current environment
has no MATLAB or FieldTrip source, so those call paths have not been changed or
claimed as validated; `test_forward_fieldtrip` reports this as skipped.
