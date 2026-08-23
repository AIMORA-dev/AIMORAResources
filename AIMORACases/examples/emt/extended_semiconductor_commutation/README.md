# Generic Extended Semiconductor Commutation

This executable public case exercises AIMORA's generic recovered-charge, nonlinear-junction-charge, event-energy-map, and passive two-stage thermal components through the public `PowerSemiconductorSwitch` interface and an explicitly activated production backend.

The parameters are synthetic and have no manufacturer identity. The case demonstrates deterministic charge depletion, displacement current, nondecreasing accepted dissipated energy, and bounded passive temperature; it does not claim arbitrary SPICE or encrypted-model compatibility, manufacturer prediction, destructive failure, lifetime, standard conformance, ATP/PSCAD equivalence, or certification.

## Run

From this directory, use `make run`. The equivalent direct command is `julia run.jl`. The case requires an explicitly activated AIMORA solver backend because it executes the coupled nonlinear network; loading the public case package alone does not expose or initialize private solver source.

## Output artifacts

The runner writes `extended_semiconductor_commutation.csv`, three SVG figures, and `summary.md` under the ignored `output/` directory unless an alternate artifact directory is supplied. The CSV contains terminal voltage, commanded network current, accepted device current, stored recovery charge, displacement current, junction temperature, and cumulative dissipated energy for every accepted timestep. `extended_semiconductor_commutation.svg` compares drive and accepted terminal current, `extended_semiconductor_charge.svg` shows recovery charge and displacement current, and `extended_semiconductor_electrothermal.svg` shows junction-temperature rise and cumulative energy.

Inspect the charge column around the imposed reverse-current interval: it should remain nonnegative and deplete after commutation. Cumulative dissipated energy should never decrease, all reported values should remain finite, and junction temperature should stay inside the declared 200–600 K domain. The summary identifies the timestep, sample count, final charge, peak reverse current, final temperature, energy, private-backend requirement, and unsupported claims. These checks demonstrate the named generic synthetic fidelity only; they do not establish manufacturer, arbitrary compact-model, ATP/PSCAD, standards, lifetime, destructive-failure, or certification equivalence.
