# Consistent EMT Initialization and Mapped Case Sequencing

This Julia-only example constructs a three-node R-L network directly at its declared 50 Hz equilibrium, evaluates both physical-frequency and timestep-matched harmonic formulations on a 10/50/70 Hz scan, initializes companion histories and complete runtime state with an explicit 500 μs probe timestep, imports one typed peak node-voltage operating quantity, and maps the accepted first-case state into a second isolated data case.

For the physical-frequency formulation, AIMORA solves

\[
\boldsymbol Y(j\omega)\,\underline{\boldsymbol V}=\underline{\boldsymbol I},\qquad \omega=2\pi f.
\]

For a trapezoidal companion with timestep \(h\), the timestep-matched formulation evaluates reactive elements at

\[
\omega_h=\frac{2}{h}\tan\!\left(\frac{\omega h}{2}\right),
\]

so the timestep-matched phasors satisfy the same discrete recurrence used by the first EMT step. The two formulations converge as the timestep is refined but are intentionally not identical at finite \(h\); AIMORA reports the finite-step transient metric for each accepted formulation rather than conflating their harmonic equations.

The imported operating quantity declares volts, peak node-to-ground basis, node-to-ground orientation, exact synthetic provenance, and the deterministic source-state signature. AIMORA reports the converted target, mapping residual, reaction current, topology/rank/condition diagnostics, initialized state owners, no-artificial-transient metrics, and the new accepted-state signature. A missing or stale source signature is a typed failure; the public workflow never settles the model through a hidden pre-simulation.

## Run

```bash
make run
```

## Results

- `frequency_scan.csv` records every physical and timestep-matched scan point, node phasor, topology classification, condition estimate, residual, symmetry, passivity, and acceptance flag.
- `formulation_comparison.csv` compares the physical and timestep-matched 50 Hz node phasors.
- `state_inventory.csv` lists the initialized algebraic, history, topology, energy, output, and checkpoint owners for both sequence cases.
- `operating_point_mapping.csv` records the second-case typed conversion, residual, uncertainty, and reaction current.
- `initialized_waveforms.csv` and `initialized_waveforms.svg` compare the two initialized load-voltage traces.
- `summary.md` records deterministic signatures, scan/mapping/transient checks, and the declared validity boundary.

## Validity and limits

The network is a compact synthetic passive R-L ladder using peak volts, ohms, henries, seconds, and hertz. It demonstrates unique referenced topology, one typed voltage mapping, exact case dependency, deterministic restart state, and short undisturbed first-step behavior; it is not a power-flow replacement, equipment recommendation, proprietary simulator comparison, or proof for unsupported apparatus families.
