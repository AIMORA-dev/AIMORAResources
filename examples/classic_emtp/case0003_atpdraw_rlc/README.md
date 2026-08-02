# Classic Case 0003 — ATPDraw RLC Network

## Purpose

This example proves that an ATPDraw-originated fixed-card network can be
normalized once and then run directly through AIMORA's Julia parser and EMT
engine. It includes explicit initial conditions and a switch event at 10 ms.

## Model

The network contains a 26.5 legacy inductance-field branch, a 1 Ω resistor,
a capacitor field value of \(10^3\), and a 12-unit type-11 source. Each dynamic
branch contributes a trapezoidal companion:

\[
i_L^n=G_L v_L^n+i_{L,\mathrm{hist}}^n,\quad
G_L=\frac{\Delta t}{2L},
\]

\[
i_C^n=G_C v_C^n+i_{C,\mathrm{hist}}^n,\quad
G_C=\frac{2C}{\Delta t}.
\]

The switch changes the nodal admittance at 10 ms. AIMORA then updates the
history sources using the accepted post-solve voltages/currents.

## Run

```bash
make run
```

The original deck requests 300 ms. The teaching runner plots the first 50 ms,
which includes the switching event and immediate response, with at most 2,001
recorded points.

## Results

- `outputs/classic_case0003_atpdraw_rlc_timeseries.csv`
- `outputs/classic_case0003_atpdraw_rlc_waveforms.svg`
- `outputs/summary.md`

Look for the discontinuity in derivative—not an impossible discontinuity in
capacitor voltage—at the switching instant. See [../SOURCE.md](../SOURCE.md)
for the exact slash-marker normalization.
