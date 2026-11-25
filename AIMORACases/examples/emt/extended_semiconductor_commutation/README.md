# Generic Extended Semiconductor Commutation

This executable public case exercises AIMORA's generic recovered-charge, nonlinear-junction-charge, event-energy-map, and passive two-stage thermal components through the public `PowerSemiconductorSwitch` interface and an explicitly activated production backend.

The parameters are synthetic and have no manufacturer identity. The case demonstrates deterministic charge depletion, displacement current, nondecreasing accepted dissipated energy, and bounded passive temperature; it does not claim arbitrary SPICE or encrypted-model compatibility, manufacturer prediction, destructive failure, lifetime, standard conformance, ATP/PSCAD equivalence, or certification.

## Run

From this directory, use `make run`. The equivalent direct command is `julia run.jl`. The case requires an explicitly activated AIMORA solver backend because it executes the coupled nonlinear network; loading the public case package alone does not expose or initialize private solver source.

The same runner also solves a two-node circuit where a conductance links the recovered diode and a gated IGBT with an exponential turn-off tail. It applies gate-off and gate-on edges, checks recovered-charge exhaustion and tail cutoff, and restores a checkpoint taken while both recovered charge and tail current are nonzero. Every resumed row must exactly match the uninterrupted signed current, charge, gate and recovery event counters, switching energy, and two-stage temperature history.

## Output artifacts

The runner writes `extended_semiconductor_commutation.csv`, three SVG figures, and `summary.md` under the ignored `output/` directory unless an alternate artifact directory is supplied. The CSV contains terminal voltage, commanded network current, accepted device current, stored recovery charge, displacement current, junction temperature, and cumulative dissipated energy for every accepted timestep. `extended_semiconductor_commutation.svg` compares drive and accepted terminal current, `extended_semiconductor_charge.svg` shows recovery charge and displacement current, and `extended_semiconductor_electrothermal.svg` shows junction-temperature rise and cumulative energy.

`gated_commutation_restart.csv` records the coupled trace on a 0.1 µs grid, including signed terminal currents, stored charge, tail current, gate state, event counts, energy, and thermal stage temperatures. It includes both node KCL and thermal balance residuals.

The diode constructor starts at 20 µC of recovered charge at time zero. The summary key `initial_recovery_charge_c` reports the first accepted sample at 1 µs, about 16.67 µC on the current companion. The reported peak reverse current is the most negative total terminal current, including displacement.

Inspect the charge column around the imposed reverse-current interval: it should remain nonnegative and deplete after commutation. Cumulative dissipated energy should never decrease, all reported values should remain finite, and junction temperature should stay inside the declared 200–600 K domain. The summary identifies the timestep, sample count, final charge, peak reverse current, final temperature, energy, private-backend requirement, and unsupported claims. These checks demonstrate the named generic synthetic fidelity only; they do not establish manufacturer, arbitrary compact-model, ATP/PSCAD, standards, lifetime, destructive-failure, or certification equivalence.
