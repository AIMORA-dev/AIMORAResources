# Classic Case 0008 — Back-to-Back Capacitor Banks

## Purpose

This three-phase case switches two delta-connected capacitor banks onto the
same bus through current-limiting reactors. The first bank closes at 0.5 ms and
the second at 17.2 ms.

## Model and equations

Immediately after the second closing, the dominant exchange between bank
capacitances and the limiting inductance is approximately

\[
\omega_{\mathrm{inrush}}\approx
\sqrt{\frac{C_1+C_2}{L_{\mathrm{lim}}C_1C_2}},
\qquad
i_L=L_{\mathrm{lim}}^{-1}\int(v_1-v_2)\,dt.
\]

The exact AIMORA solution uses the full three-phase nodal system, phase
coupling, source impedances, switch states, and companion history sources. The
input timestep is 10 µs and the original horizon is 40 ms.

## Run and outputs

```bash
make run
```

The generated SVG should show distinct changes near 0.5 ms and 17.2 ms. The
second transition is the back-to-back event: an already charged bank can drive
a high-frequency current into the newly connected bank. Use the CSV for exact
channel values and `summary.md` for extrema and dimensions.

The exact waveform artifacts are `classic_case0008_back_to_back_capacitor_banks_timeseries.csv` and `classic_case0008_back_to_back_capacitor_banks_waveforms.svg`.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
