# Transformer and Reactor Hierarchy

AIMORA provides seven explicitly selected fixed-step instantaneous-EMT transformer tiers. A tier is a physical and numerical contract, not a quality label: users should select the least expensive tier that represents the quantities and phenomena required by the study. AIMORA never promotes a lower-tier state to a higher-tier interpretation, infers missing vendor data, or fills an unavailable internal quantity with zero.

## Tier selection

| Tier | Representation | Admitted interpretation | Deliberately unavailable |
| --- | --- | --- | --- |
| Low-frequency terminal | Complete coupled terminal R-L-C-G matrices | Ordered terminal voltage/current, leakage and declared shunts at the admitted low-frequency timestep | Core-local flux and winding internal voltage |
| BCTRAN terminal | Pair-test and positive/zero-sequence reconstruction into a complete terminal matrix | Multiwinding and three-phase terminal behavior, test reconstruction, grounding and zero-sequence paths | Unrepresented core and winding-section quantities |
| Hybrid transformer | Explicit leakage, capacitance, frequency-loss state and topological nonlinear core | Coil and core-branch flux/mmf, saturation, hysteresis/remanence and separated loss state when declared | Unrepresented turn/section voltage |
| Magnetic-equivalent circuit | Coupled electrical circuit and explicit connected magnetic graph | Magnetic-node continuity, branch flux/mmf/material state and signed winding coupling | Geometry-complete winding stress |
| Wideband black box | Real stable causal reciprocal positive-real multiport realization | Complete fitted external-port response and passive rational state within its exact band | Physical core, turn or winding-section interpretation |
| Grey-box ladder | Declared passive physical R-L-C-G ladder | Only the explicitly represented ladder-node voltages and branch currents | Any unrepresented turn or unique inverse identification claim |
| White-box winding | Geometry-owned complete coupled multiconductor winding sections | Declared section voltages/currents, charge, propagation and loss within the admitted mesh and band | Field, insulation-life or destructive-failure prediction |

The immutable tier, terminal/winding/branch/section order, source identity, settings and validity domain travel through preparation, runtime state, results and snapshots. A request with incomplete topology, indefinite passive matrices, an unsupported material, an out-of-band response, an unresolved timestep or a stale identity returns a typed refusal instead of falling back.

## Equations, units and signs

All runtime electrical quantities use peak instantaneous SI values. Terminal current is positive into the apparatus and supplied electrical power is

```math
p(t)=v(t)^\mathsf{T}i(t).
```

Terminal and represented-network tiers use coupled branch and nodal equations of the form

```math
v=Ri+L\frac{di}{dt},\qquad i_C=C\frac{dv}{dt},\qquad i_G=Gv,
```

with complete symmetric coupled matrices on their declared physical subspaces. Fixed-step trapezoidal companions are the default; localized discontinuities use the admitted backward-Euler transaction and restore every trial state on rejection. The first trapezoidal step after a discontinuity preserves the accepted left-end physical current and accounts separately for newly applied passive fault conductance.

Magnetic tiers use one signed turns matrix in both directions:

```math
F_\mathrm{coil}=Ni,\qquad \lambda=N^\mathsf{T}\Phi,\qquad v_\mathrm{induced}=\frac{d\lambda}{dt},\qquad A_m\Phi=0.
```

This shared sign convention prevents ideal coupling from creating energy. Magnetic material equations provide branch mmf drop, stored energy and differential reluctance; hysteretic material state additionally owns direction, reversal memory, remanence and loop loss. Classical eddy and excess losses are separate nonnegative terms rather than aliases for static hysteresis.

The public interfaces distinguish volts, amperes, ohms, siemens, henries, farads, webers, tesla, ampere-turns, watts, joules, seconds, hertz, radians and geometry units. RMS nameplate or test data cross into peak instantaneous values exactly once through a declared single- or three-phase base. Phase order, winding polarity, dot convention, vector-group clock, zero-sequence basis and the ``\exp(j\omega t)`` convention are explicit data.

## Connections, cores and reactors

Connection behavior comes from an explicit incidence and polarity matrix. Vector-group text checks that matrix but never creates hidden nodes. Grounded and ungrounded wye, delta circulation, neutral impedance, phase shift, multiwinding order and zero-sequence passage are therefore topology rather than labels.

Magnetic-equivalent and hybrid models use connected branch graphs with physical length, cross-section, air-gap and material ownership. Coil mmf injection, magnetic continuity and flux linkage are solved together with the electrical network. Leakage represented outside the core graph is not counted again inside it.

The same apparatus contracts cover air-core and iron-core shunt, series, neutral and smoothing reactor constructions. Air-core products carry no invented ferromagnetic state. Iron-core products expose only the magnetic material, topology, gap/fringing approximation and control application actually declared; a generic reactor is not an arc-suppression, HVDC, insulation or certification result.

## State, initialization and events

Accepted state includes every tier-applicable branch current, capacitor history, rational state, represented node voltage, magnetic flux/mmf/material memory, loss and energy accumulator, topology mode, event cursor and output cursor. Trial residual and Jacobian evaluation do not mutate accepted state. Acceptance changes all state once, while rejection restores all state and signatures.

Each tier supports an explicit de-energized state and model-consistent sinusoidal initialization within its declared domain. Initialization checks terminal KCL, magnetic continuity, vector-group and zero-sequence relations, stored energy and all discrete histories. It does not hide an artificial settling interval.

Events include terminal faults and the tier-admitted breaker, grounding, winding/internal-fault, tap and phase-shift changes. Events are localized on accepted boundaries, ordered deterministically and followed by a coupled re-solve. Passive fault energy, device dissipation and method-local numerical dissipation are distinct diagnostics; unexplained active energy is rejected.

Snapshots bind the complete state to the preparation identity. Restoring a compatible snapshot must reproduce uninterrupted continuation exactly, including the event cursor, represented internal state, histories, energy and deterministic result signature. A tier, topology, source, timestep, order or schema mismatch refuses restore.

## Public executable products

Each public product runs 1,000 fixed 10 µs steps, applies one terminal fault at 5 ms, writes typed terminal and tier-specific results, captures a midpoint checkpoint and requires exact replay. Each directory contains a concise report, waveform CSV, summary and curated SVG generated by its Julia runner.

- [Low-frequency terminal transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_low_frequency)
- [Three-phase three-winding BCTRAN transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_bctran)
- [Hybrid nonlinear-core transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_hybrid)
- [Magnetic-equivalent-circuit transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_magnetic_equivalent)
- [Twelve-port wideband black-box transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_wideband_black_box)
- [Thirty-two-node grey-box ladder](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_grey_box)
- [Four-winding sectioned white-box transformer](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/transformer_white_box)

The matching public catalog records preserve the exact tier, SI bases, parameter nature, source, transformation, uncertainty, rights, validity and unsupported phenomena. These are generic synthetic examples, not manufacturer records.

## Evidence and performance boundary

Independent formulations check connection and signed-turn matrices, pair-test reconstruction, direct companions, magnetic continuity and constitutive behavior, hysteresis memory and loss, passive multiport recurrence, physical ladders and winding sections without reusing the production stamp or history implementation. Analytical limits, timestep and section refinement, permutation metamorphisms, fault rollback, energy/passivity, uncertainty alternatives and deliberate mutations bound the evidence.

Executable overlap is limited to exact lawfully redistributable or locally available models: named historical BPA transformer behavior, pinned headless OpenModelica/Modelica Standard Library equations and ngspice passive ladder circuits. These overlaps validate only their exact mapped variables, versions, assumptions, units, timestep/frequency grids and artifacts; they do not establish ATP/PSCAD equivalence.

Performance evidence compares identical tier, topology, state, timestep, event, outputs and accuracy. It reports setup, preparation, warmed stepping, allocations and retained output separately. A faster lower tier or omitted internal output is not an equal-accuracy optimization.

## Limits

The released hierarchy does not claim arbitrary vendor or proprietary models, hidden ATP/PSCAD behavior, protected-standard conformance, measurement or field accuracy, insulation coordination/design, thermal aging, lifetime, destructive failure, HIL qualification or certification. Frequency-band, timestep, mesh, section, material, source and uncertainty limits in each result remain controlling; unknown uncertainty remains unknown.
