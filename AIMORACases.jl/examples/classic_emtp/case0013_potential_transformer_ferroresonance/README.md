# Classic Case 0013 — Potential-Transformer Ferroresonance

## Purpose

This case studies ferroresonance of a potential transformer connected to a
345 kV bus through SF₆ breaker grading capacitances. The source-side breakers
open at 20 ms, leaving a weak capacitive supply coupled to a nonlinear
magnetizing branch.

## Governing equations

Transformer flux linkage and winding voltage satisfy

\[
v=N\frac{d\Phi}{dt}=\frac{d\lambda}{dt},
\]

while the magnetizing current is nonlinear,

\[
i_m=f(\lambda).
\]

Together with the grading capacitance,

\[
C_g\frac{dv}{dt}+i_m(\lambda)+i_{\mathrm{network}}=0.
\]

The nonlinear \(f(\lambda)\) curve contains the knee that allows multiple
oscillation regimes. AIMORA iterates the nonlinear companion at each accepted
timestep and preserves state across the switch event.

## Run and outputs

```bash
make run
```

The full 0.2 s deck is executed at 25 µs. Inspect the post-20 ms waveform for
non-sinusoidal voltage, amplitude modulation, or sustained nonlinear
oscillation. `summary.md` reports observed extrema without claiming that every
parameter choice must enter ferroresonance.

The exact artifacts are `classic_case0013_potential_transformer_ferroresonance_timeseries.csv`, `classic_case0013_potential_transformer_ferroresonance_waveforms.svg`, and `summary.md`.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
