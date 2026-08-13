# Generic Bridge Topologies

AIMORA provides dependency-light public contracts for composing accepted semiconductor switches and passive branches into named switching-detailed bridge hardware. The aggregate preserves each constituent device as the physical owner and supplies a stable oriented incidence, admissible gate-state groups, fault/block state, deterministic signatures, public terminal traces, passive charge and flux, and aggregate power and energy accounting.

## Admitted families

The current library covers single-phase Graetz diode, thyristor, and half-controlled bridges; one-through-twelve-phase natural or self-commutated bridges; two-level and full bridges; step-down, step-up, and bidirectional choppers; one-through-four isolated series or parallel groups; three-level neutral-point-clamped, T-type, and flying-capacitor legs; and one-through-sixteen-cell cascaded H-bridge phases.

The public descriptors validate unique terminal and position identities, exact branch orientation, family count bounds, passive placement, group connectivity, finite state tables, physical provenance, licence, and redistribution status. `bridge_topology_incidence` exposes the declared node-by-branch matrix, while `bridge_topology_state_is_allowed` checks a complete ordered gate request against the local hardware constraints.

## Runtime ownership

`PowerSemiconductorBridgeTopology` composes exact `PowerSemiconductorSwitch` objects and finite passive branch owners. Baseline valves participate in the aggregate linear stamp. A valve selecting nonlinear extended fidelity is omitted from that stamp and registered exactly once with the nonlinear nodal owner; duplicate or absent registration is rejected. Gate operations, faults, block/restart, passive histories, and all selected device states participate in the accepted transaction and checkpoint.

The typed aggregate state reports external terminal voltage and current, requested/applied/conducting position matrices, passive voltage/current/charge/flux, terminal KCL residual, instantaneous terminal power, losses, stored and dissipated energy, fault and block state, counters, topology signature, and deterministic state signature.

## Public case and catalogue

The public case `emt_generic_bridge_topology_library` executes eleven mixed aggregates and 52 valve positions through the real nodal and nonlinear paths. Its exact scheduled sequence covers gate changes, block/restart, a stuck-open fault and recovery, three-level redundant states, flying-capacitor state, opposite cascaded-cell polarity, one nonlinear junction-charge valve, and split-checkpoint replay. It commits a deterministic CSV, a topology-state SVG, a terminal/passive-voltage SVG, and a scalar summary. The catalogue entry `generic_bridge_topology_library` records the exact admitted family/count boundary and synthetic provenance.

## Limits

This library owns hardware topology and accepted constituent state, not modulation, converter control, transformer/filter/DC-system design, arbitrary graph synthesis, complete FACTS/HVDC/MMC plants, vendor prediction, destructive failure, ATP/PSCAD equivalence, protected-standard conformance, HIL qualification, or certification. An admitted topology does not imply that an unqualified control, system connection, parameter set, or application is accepted.
