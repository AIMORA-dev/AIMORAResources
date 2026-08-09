# Nonlinear Network Discontinuity

This AIMORA-authored instantaneous-EMT example couples a fixed ideal source, a series RLC companion, a passive shunt conductance, a fitted odd-symmetric ZnO current branch, and a switched current injection. It also executes an independent eight-node manufactured network whose exact solution is preserved across a real sparse-topology change. Both slices demonstrate the reusable physical residual/Jacobian contract and the private scaled safeguarded network solve without copying a proprietary ATP or PSCAD model.

## Model, units, and assumptions

Voltages are volts, currents are amperes, resistance is ohms, inductance is henries, capacitance is farads, time is seconds, and energy is joules. The ideal constraint holds source node 1 at 400 V, the series branch is 5 Ω, 10 mH, and 20 µF, the load conductance is 0.01 S, and a 0.25 A injection begins exactly at 0.8 ms. The synthetic ZnO samples follow a positive continuous power law and are fitted through AIMORA's existing characteristic owner before they enter the nonlinear network.

## Numerical treatment

The source energization and switched-current edge are declared localized discontinuities and each uses two accepted backward-Euler half steps; all other steps use trapezoidal companions. The localized edge is explicitly vetoed as a numerical-chatter candidate, while waveform increments that do not satisfy the complete alternating, amplitude, and ratio predicate remain undamped. The example solves the same network at 20, 10, and 5 µs, reports the refinement envelope, captures accepted nonlinear state without factor objects, deliberately mutates it with a probe step, restores it, and verifies bitwise continuation against the uninterrupted trajectory. The typed study calendar independently reproduces the manual 10 µs trajectory bitwise, while the eight-node manufactured slice verifies its exact voltage and ideal-constraint current before and after one topology-signature change, one symbolic rebuild, and subsequent sparse-factor reuse.

## Run

```bash
make run
```

## Outputs

- `waveform.csv` and `waveform.svg` show the finest-step load voltage, RLC current, solver-reported nonlinear-device power, and stored energy.
- `convergence.csv` aligns the 20, 10, and 5 µs load-voltage solutions on the coarse grid.
- `restart_comparison.csv` compares uninterrupted and restored 10 µs trajectories.
- `manufactured_topology.csv` records all eight exact manufactured node voltages across the sparse topology change.
- `summary.md` records KCL, constraint, solver-versus-independent device-power agreement, passivity, energy, event, chatter, factorization, refinement, and restart diagnostics.

The case validates only the declared synthetic network, numerical formulation, and timestep range. It is not an ATP/PSCAD equivalence, manufacturer arrester qualification, measured-network validation, insulation-coordination study, or certification claim.
