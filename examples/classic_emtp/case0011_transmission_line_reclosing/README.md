# Classic Case 0011 — Transmission-Line Reclosing

## Purpose

A fault is applied at the receiving end of a 120-mile line. The sending-end
breaker opens at 20 ms, isolating the line and leaving trapped charge. This
case combines distributed line history, transformer saturation data, switching,
and two three-phase source equivalents.

## Governing model

For a travelling-wave mode with surge impedance \(Z_c\) and travel time
\(\tau\),

\[
v_k(t)+Z_ci_k(t)=v_m(t-\tau)-Z_ci_m(t-\tau).
\]

The delayed opposite-end quantity becomes the line's history source in the
current nodal solve. Breaker opening changes the active topology but must not
erase the delay buffers or capacitor/transformer state.

The deck uses \(\Delta t=33.3\) µs, an 80 ms requested horizon, a 20 ms main
breaker opening, and a fault-switch schedule. Fixed-field spelling errors in
the public source were corrected without changing electrical values.

## Run and outputs

```bash
make run
```

The CSV includes terminal and requested physical channels; the SVG emphasizes
the requested outputs. Look for the fault response, the 20 ms isolation, and
the post-opening trapped-charge waveform. The final recorded time is the
nearest integer timestep not exceeding 80 ms.

The exact artifacts are `classic_case0011_transmission_line_reclosing_timeseries.csv`, `classic_case0011_transmission_line_reclosing_waveforms.svg`, and `summary.md`.

Provenance and exact repairs: [../SOURCE.md](../SOURCE.md).
