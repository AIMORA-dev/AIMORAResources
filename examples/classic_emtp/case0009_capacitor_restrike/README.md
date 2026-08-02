# Classic Case 0009 — Capacitor-Switch Restrike

## Purpose

This variation of the back-to-back bank system opens phase A and then restrikes
at 11.1 ms. A later 0.9172 s bank event is also present, which is why the
accepted deck horizon was extended beyond the unreachable 40 ms upstream
horizon.

## Model and equations

Before restrike, charge can remain trapped on the isolated capacitor. At
restrike, the voltage difference across the gap is applied to the limiting
network:

\[
v_{\mathrm{gap}}=v_{\mathrm{bus}}-v_{\mathrm{bank}},\qquad
L\frac{di}{dt}+Ri=v_{\mathrm{gap}}.
\]

The abrupt topology change can create high \(di/dt\) and an oscillatory
exchange with the bank capacitance. AIMORA represents the switch as an
admittance mutation at its scheduled time while preserving branch history.

## Run and outputs

```bash
make run
```

The runner computes 1.0 s of the 1.2 s accepted deck, including both the
11.1 ms restrike and the 0.9172 s event, while recording at most 2,001 samples.
Use the CSV—not only the downsampled SVG—when inspecting exact extrema and
event timing. `summary.md` states the plotted horizon and sample count.

The waveform should show a fast oscillatory change at restrike superimposed on
the power-frequency envelope. Provenance: [../SOURCE.md](../SOURCE.md).

The exact artifacts are `classic_case0009_capacitor_restrike_timeseries.csv`, `classic_case0009_capacitor_restrike_waveforms.svg`, and `summary.md`.
