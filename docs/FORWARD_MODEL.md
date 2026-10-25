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
