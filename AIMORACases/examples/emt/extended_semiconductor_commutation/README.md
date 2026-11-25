# Generic Extended Semiconductor Commutation

This executable public case exercises AIMORA's generic recovered-charge, nonlinear-junction-charge, event-energy-map, and passive two-stage thermal components through the public `PowerSemiconductorSwitch` interface and an explicitly activated production backend.

The parameters are synthetic and have no manufacturer identity. The case demonstrates deterministic charge depletion, displacement current, nondecreasing accepted dissipated energy, and bounded passive temperature; it does not claim arbitrary SPICE or encrypted-model compatibility, manufacturer prediction, destructive failure, lifetime, standard conformance, ATP/PSCAD equivalence, or certification.

## Run

From this directory, use `make run`. The equivalent direct command is `julia run.jl`. The case requires an explicitly activated AIMORA solver backend because it executes the coupled nonlinear network; loading the public case package alone does not expose or initialize private solver source.

The recovered diode takes its declared SI parameters from the generic EMT catalog facet. To run with a separate copy of that card, pass the output directory and card path as the first and second arguments to `run.jl`. The synthetic drive, event-energy values and gated IGBT are defined by the example.

The same runner also solves a two-node circuit where a conductance links the recovered diode and a gated IGBT with an exponential turn-off tail. It applies gate-off and gate-on edges, checks recovered-charge exhaustion and tail cutoff, and restores a checkpoint taken while both recovered charge and tail current are nonzero. Every resumed row must exactly match the uninterrupted signed current, charge, gate and recovery event counters, switching energy, and two-stage temperature history.

## Output artifacts

The runner writes `extended_semiconductor_commutation.csv`, three SVG figures, and `summary.md` under the ignored `output/` directory unless an alternate artifact directory is supplied. The CSV contains terminal voltage, commanded network current, accepted device current, stored recovery charge, displacement current, junction temperature, and cumulative dissipated energy for every accepted timestep. `extended_semiconductor_commutation.svg` compares drive and accepted terminal current, `extended_semiconductor_charge.svg` shows recovery charge and displacement current, and `extended_semiconductor_electrothermal.svg` shows junction-temperature rise and cumulative energy.

`gated_commutation_restart.csv` records the coupled trace on a 0.1 µs grid, including signed terminal currents, stored charge, tail current, gate state, event counts, energy, and thermal stage temperatures. It includes both node KCL and thermal balance residuals.

The separate `semiconductor_event_energy_lookups.csv` lists committed map lookups in device and coupled traces. Each row gives the network device index, event kind, physical time and side, publication interval and order within it, lookup magnitudes in amperes and volts, pre-impulse temperature in kelvin, and mapped energy in joules. The lookup current can differ from total terminal current. A physical boundary can have more than one lookup: at 30.1 µs the coupled diode reports right-side reverse recovery, then reports turn-off at the same physical clock from the left of the next interval. The stream includes mapped zero-energy events and excludes retries that fail to commit.

The companion file `semiconductor_event_energy_margins_v1.csv` uses the same event key. It records the distances to each full map axis and to the faces of the cell used for interpolation, in A, V and K. These distances describe each lookup point. The solver also exposes accepted signed total-current margins separately when a model declares a terminal-current interval. This public case leaves that interval undeclared.

The separate `semiconductor_timestep_resolution_v1.csv` describes each positive-duration accepted substep for installed recovery, tail and nonlinear junction-charge components. It lists the integration method, actual duration, component participation and declared time constant. For known constants, it reports the ratio of time constant to duration and whether twenty times the duration fits within that constant. Boundary actions contribute no timestep. The first limiting participating interval is flagged per component and trace.

For the diode's 1 µs intervals and 5 µs recovery lifetime, the ratio is 5 and falls short of 20. The coupled trace reaches minimum participating ratios of 50 for recovery and 40 for tail decay. The nonlinear junction capacitance does not by itself define a circuit time constant, so its scale and resolution verdict are unavailable. The existing grid-refinement evidence is separate. These ratios leave whole-device timestep adequacy unresolved.

The summary reads declared provenance from the Engine's version-2 extended result. It lists the diode, the gated IGBT, and their event-energy tables separately. Their declarations are unknown uncertainty. The case presents no numerical uncertainty interval or distribution. Only approved generic declarations are written to its public summary; other text is withheld. The Engine retains the full typed declaration for local callers. A version-1 physical result can be viewed with provenance explicitly unavailable.

The diode constructor starts at 20 µC of recovered charge at time zero. The summary key `initial_recovery_charge_c` reports the first accepted sample at 1 µs, about 16.67 µC on the current companion. The reported peak reverse current is the most negative total terminal current, including displacement.

At the diode's recovered-charge exhaustion, the solver uses two backward-Euler substeps. Their channel work and electrical loss use the accepted right-end current and voltage, while the junction companion reports its numerical work separately from heat. The electrical loss history and Cauer input use the same continuous channel and active-tail heat. On smooth trapezoidal steps that amount comes from endpoint-average power. A sampled endpoint switching impulse uses the temperature after continuous evolution and is deposited separately.

Inspect the charge column around the imposed reverse-current interval: it should remain nonnegative and deplete after commutation. Cumulative dissipated energy should never decrease, all reported values should remain finite, and junction temperature should stay inside the declared 200–600 K domain. The summary identifies the timestep, sample count, final charge, peak reverse current, final temperature, energy, private-backend requirement, and unsupported claims. These checks demonstrate the named generic synthetic fidelity only; they do not establish manufacturer, arbitrary compact-model, ATP/PSCAD, standards, lifetime, destructive-failure, or certification equivalence.
