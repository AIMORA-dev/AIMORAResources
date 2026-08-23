# Generic Bridge Topology Library

This public synthetic case composes the accepted semiconductor-switch owner into diode and thyristor Graetz bridges, a complementary full bridge, step-down, step-up, and bidirectional choppers, a two-group polyphase rectifier, neutral-point-clamped and T-type legs, a flying-capacitor leg, and a two-cell cascaded H-bridge phase. One Graetz valve also selects the generic nonlinear junction-charge fidelity so the mixed network executes both the linear aggregate stamps and the private nonlinear nodal path.

The source and load values are AIMORA-authored generic SI inputs with no manufacturer identity. Exact scheduled operations exercise complementary gate changes, block and restart, a stuck-open position and recovery, three-level redundant states, flying-capacitor charge, and opposite cascaded-cell polarities. The runner checks finite accepted state, aggregate terminal KCL, nonnegative passive storage and dissipation, exact split-checkpoint replay, and deterministic topology/state signatures.

## Run

Run this case from an AIMORA owner worktree in a Julia process where the production solver backend has been explicitly activated, then include `run.jl` with the output directory as its first argument. `make run` is also available when the selected Julia environment already activates that backend. Loading `AIMORACases` or the public topology contracts alone never initializes or exposes the private solver.

## Output artifacts

The committed `outputs/` directory contains `generic_bridge_topology_library.csv`, the `generic_bridge_topology_states.svg` and `generic_bridge_topology_physics.svg` plots, and `summary.md`. The waveform table reports the total conducting positions, requested positions, transition count, maximum topology KCL residual, passive stored energy, total loss, representative DC and flying-capacitor voltages, and the number of blocked topologies at every accepted timestep. Inspect the state plot for discrete changes at block, restart, fault, and three-level gate operations; inspect the physics plot for finite continuous network response. The summary should confirm exact split replay, eleven distinct final signatures, a KCL residual below the declared tolerance, and nonnegative passive storage.

This case establishes only the named generic topology, state, event, passive, and terminal contracts. It does not supply modulation or converter controls, transformer/filter/DC-system design, arbitrary topology synthesis, vendor prediction, destructive failure, ATP/PSCAD equivalence, protected-standard conformance, HIL qualification, or certification.
