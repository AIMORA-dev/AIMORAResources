# Local Multirate and Partitioned EMT Network

This redistributable Julia case executes one analytic passive two-region boundary and one explicitly declared eight-region local-multirate EMT network. The coupled network retains the same physical model owners used by monolithic instantaneous EMT: a source and feed, a Semlyen frequency-dependent history line, an instrument transformer and sampled measurement, a passive filter, a modern permanent-magnet machine, a switch-detailed converter leg and PWM task, a timed topology transition, and a terminal load.

The eight regions communicate through seven oriented voltage/current ports. Their local steps use three exact commensurate rates. The 80 microsecond physical transition is both a topology event and a machine event; every region and interface rolls back together if a window fails. The runner checkpoints the accepted state at that transition and proves byte-stable result equality after a split restore, including line histories, machine state, measurement state, PWM scheduling, bridge state, topology, interface traces, and deterministic signatures.

## Run

From this directory, run `make run`. The equivalent direct command is `julia --project=../../.. run.jl outputs`. Execution requires an explicitly activated AIMORA production backend. Public package loading, plan construction, project inspection, result types, and documentation remain solver-free.

## Output artifacts

The runner writes `local_multirate_partitioned_network.csv` with positive voltage, negative voltage, and oriented current for all seven interfaces at every accepted communication point. `local_partition_interface_voltage.svg` and `local_partition_interface_current.svg` provide curated views of the source-side, middle, and load-side boundaries. `local_partition_refinement.csv` and `local_partition_refinement.svg` show passive normalized endpoint convergence at 5, 2.5, and 1.25 microsecond communication steps. `summary.md` records region/rate/window work, the physical event, interface voltage/KCL/energy residuals, the three-rate and equal-step monolithic differences, the passive two-region limit error, exact restart signatures, and unsupported claims.

The parameters are synthetic and redistributable. This case demonstrates explicit local fixed-step subcycling, conservative causal interface exchange, coordinated events and restart, and communication-step refinement on the declared network only. It does not claim automatic partition inference, noncommensurate or variable global steps, FMI/SSP/HELICS compatibility, distributed or networked co-simulation, GPU execution, DASSL, hard-real-time/HIL behavior, universal active-interface stability, standard conformance, ATP/PSCAD compatibility, or certification.
