# Local Multirate and Partitioned EMT

AIMORA can execute one fixed-step instantaneous-EMT study as explicitly declared local regions with exact commensurate substeps. Each physical model and every mutable state owner belongs to exactly one region. Regions meet only through declared, oriented interface ports and synchronize at exact rational communication points. Monolithic fixed-step execution remains the default; partition execution is selected explicitly and never inferred from topology.

## Plan and ownership

An `EMTPartitionPlan` declares a start and stop instant, communication step, ordered regions, ordered ports, and exchange policy. Every `EMTPartitionRegion` names its complete model inventory and local step. Local steps must divide the communication step exactly, may use at most sixteen distinct rates, and are represented by normalized integer logical time rather than floating calendar arithmetic. Duplicate model ownership, unknown regions, repeated identities, missing terminals, and noncommensurate clocks are refused before execution.

```julia
using AIMORA
using AIMORA.EMTPartitioning
using AIMORA.EMTTaskPlatform

regions = (
    EMTPartitionRegion(
        "source_region",
        ("source", "feed"),
        emt_logical_time(5 // 1_000_000),
    ),
    EMTPartitionRegion(
        "load_region",
        ("load",),
        emt_logical_time(20 // 1_000_000),
    ),
)
port = EMTInterfacePort(
    "source_to_load",
    VoltageCurrentInterfacePort,
    "source_region",
    "load_region",
    "SOURCE_OUT",
    "LOAD_IN";
    voltage_base_v=120.0,
    current_base_a=10.0,
    reference_impedance_ohm=12.0,
)
plan = emt_partition_plan(
    regions,
    (port,);
    start=emt_logical_time(0),
    stop=emt_logical_time(1 // 1_000),
    communication_step=emt_logical_time(20 // 1_000_000),
)
```

The declaration is solver-free. Public users can construct, inspect, hash, serialize, and validate plans without access to the production backend. Physical execution requires explicit activation of a backend that advertises `:local_multirate_partitioned_emt`.

## Oriented interfaces and causal exchange

The supported public port families are voltage/current, Norton, Thevenin, scattering, and traveling-wave declarations. The current implementation executes canonical deck regions through voltage/current ports; other port kinds remain typed declarations until a backend advertises their executable capability. Each interface current is positive outward from its owning region toward the interface. The coordinator therefore applies equal and opposite regional injections and reports a KCL residual separately from the voltage-continuity residual.

At a communication window, every region receives only interface samples available at or before its local step. Zero-order and linear causal reconstruction are declared explicitly. AIMORA never reads a future neighbor state. Iterated waveform exchange evaluates the same admitted regional equations, corrects the interface-current waveform, and accepts only when every voltage residual satisfies its own absolute-plus-relative scale. This is local integration of the same physical fidelity, not a reduced equivalent or delayed lower-fidelity substitute.

## Error, conservation, and refinement

Acceptance has three independent boundaries:

- voltage continuity uses declared voltage bases and absolute/relative tolerances;
- interface KCL checks the two outward current orientations directly;
- interface energy defect integrates the voltage mismatch and exchanged current over the window and compares it with an absolute-plus-relative transferred-energy budget.

A small residual is not a universal stability proof. Communication-step refinement must also approach the equal-step or monolithic reference on the declared case, while local-step refinement retains each physical owner's own convergence requirements. A failed interface iteration, regional nonlinear solve, physical event, output mutation, or conservation check rejects the entire window.

## Events, tasks, topology, rollback, and restart

Each regional trial begins from the same last accepted state. Exact task instants and localized physical events retain their existing event-first mutation order. A topology change is applied only in its owning region, but its acceptance is coordinated across all regions and ports. If any region or interface fails, every region, task queue, nonlinear owner, history owner, output cursor, event cursor, and coordinator trace returns to the last accepted communication point.

`partitioned_emt_checkpoint` captures the complete accepted portable state: plan/study identities, region and port order, communication count, every regional continuous/discrete/history/task/event/output owner, interface waveforms and residual traces, and deterministic signatures. `restore_partitioned_emt_checkpoint!` validates the full identity before mutation. Stale, corrupt, incomplete, or cross-plan snapshots return a typed refusal and leave the destination unchanged.

## Results and diagnostics

`EMTDeckPartitionResult` reports exact region and port identities, accepted synchronization times, both terminal-voltage traces, oriented interface-current traces, per-interface voltage/KCL/energy residuals, fixed-point iterations, regional local-step counts, accepted and rejected windows, acceptance, and a deterministic signature. The result distinguishes physical residuals from numerical iteration progress; a converged fixed point cannot conceal failed KCL or energy checks.

The public [`local_multirate_partitioned_network`](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/local_multirate_partitioned_network) example contains an analytic passive two-region boundary and an eight-region coupled network. The latter combines a Semlyen history line, instrument transformer and sampled measurement, passive filter, modern machine, switch-detailed converter/PWM, timed topology transition, and load across seven interfaces and three local rates. It publishes interface CSV data, curated SVGs, communication refinement, residuals, exact split restart, and deterministic metrics.

## Performance interpretation

Partition execution has setup, regional integration, interface exchange, iteration, rollback, and output costs. P0 reports overhead on a small analytic problem. P1 retains nonlinear event/task/apparatus owners across at least three rates and two interfaces. P2 retains at least eight regions, four rates, frequency-dependent histories, and one million accepted regional local steps. Measurements report first and warmed execution, allocations, peak resident memory, regional work imbalance, exchange values, errors, and exact hardware/runtime metadata.

The registered P1 and P2 comparisons require the maximum partition-to-monolithic interface-voltage difference to remain at or below one percent of the declared 120 V interface base, or 1.2 V, while both paths retain identical equations, initialization, outputs, events, tolerances, and local-step fidelity. The P2 scale case therefore uses a 20 microsecond communication window with a 2.5 microsecond fastest regional step; an 80 microsecond communication window exceeds this equal-accuracy boundary and is not accepted merely because its internal waveform iteration converges.

Serial partition evidence does not imply parallel, distributed, GPU, or real-time speedup. A monolithic or equal-step solve may be faster for small networks. Crossover claims require equal equations, initialization, events, tasks, outputs, and error tolerances; partitioning may not win by weakening fidelity or accuracy.

## Validity and exclusions

The admitted execution domain is one through 64 explicit regions, one through 16 exact commensurate local rates, integer rate ratios through 10,000, and communication windows no longer than the shortest declared physical delay or validated estimator domain. The current production slice is deterministic serial fixed-step instantaneous EMT on supported local hardware.

The capability does not provide automatic graph partitioning, dynamic load balancing, noncommensurate or variable global steps, network faults as an automatic partition mechanism, FMI, SSP, HELICS, distributed/network transport, GPU execution, DASSL, hard-real-time/HIL scheduling, or universal stability for arbitrary active interfaces. The public case is synthetic and makes no ATP/PSCAD compatibility, standard-conformance, safety, protection-setting, or certification claim.
