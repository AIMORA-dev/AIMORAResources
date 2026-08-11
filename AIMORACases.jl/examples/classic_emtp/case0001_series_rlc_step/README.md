# Classic Case 0001 — Series RLC Step

## Purpose

This is the smallest classic EMTP input-to-waveform case. A unit step source
energizes a series resistance/inductance path connected to a shunt capacitor.
Use it to understand input cards, the timestep, companion models, and the
second-order transient before studying larger networks.

## Governing equations

With capacitor voltage \(v_C\) and series current \(i\),

\[
L\frac{di}{dt}+Ri+v_C=v_s(t),\qquad
C\frac{dv_C}{dt}=i.
\]

The undamped natural frequency and damping ratio are

\[
\omega_n=\frac{1}{\sqrt{LC}},\qquad
\zeta=\frac{R}{2}\sqrt{\frac{C}{L}}.
\]

The deck uses \(R=1.5811\) Ω, the legacy branch inductance field value 5,
the shunt capacitance field value 5, a 10 µs step, and a 10 ms horizon. AIMORA
applies the deck unit conversion and advances the RLC history terms in Julia.

## Run

```bash
make run
```

`run.jl` parses `case0001.deck`, validates it, executes the full 10 ms horizon,
and records no more than 2,001 evenly spaced samples.

## Results

- `outputs/classic_case0001_series_rlc_step_timeseries.csv`
- `outputs/classic_case0001_series_rlc_step_waveforms.svg`
- `outputs/summary.md`

The capacitor voltage should begin at its specified initial state and move
toward the forced response with damped RLC curvature. The summary reports the
actual peak, timestep, node count, and plotted duration; it does not substitute
an analytic fixture for the simulation.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
