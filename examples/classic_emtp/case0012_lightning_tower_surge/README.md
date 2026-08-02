# Classic Case 0012 — Lightning Tower Surge

## Purpose

A fast current source strikes the top of the first tower in a 230 kV line
model. Distributed tower/ground-wire/phase sections propagate the surge, and
the requested voltages show the stress across the outside-phase insulators.

## Governing model

The source is a fast exponential impulse beginning at \(t=0\). A common form
for this source family is

\[
i_s(t)=I_0\left(e^{-\alpha t}-e^{-\beta t}\right)u(t),
\]

with the exact amplitude/time parameters read from the type-13 source card.
Each distributed mode obeys

\[
\frac{\partial^2 v}{\partial x^2}=\gamma^2v,\qquad
v^+(t)=v^-(t-\tau),
\]

so reflections appear when the wave encounters tower grounding, line
junctions, and the insulator connection.

## Inputs and run

The timestep is 10.2 ns and the original horizon is 6 µs, giving 588 accepted
fixed steps. Run:

```bash
make run
```

The SVG should show arrival-time differences and reflected fast-front voltage
peaks along towers T1–T5. Use the CSV for exact peak time and polarity. Values
are simulation outputs; no illustrative sine wave is substituted for the
lightning waveform.

## Outputs and interpretation

- `classic_case0012_lightning_tower_surge_timeseries.csv` contains every sampled requested network channel.
- `classic_case0012_lightning_tower_surge_waveforms.svg` plots the selected tower/insulator surge voltages.
- `summary.md` records timestep, executed horizon, channel count, and peak magnitude.

The first arrival should appear at the nearest structure and later peaks should follow propagation/reflection delays rather than a 60 Hz phase relationship. Compare peak polarity, time, and attenuation across towers; a response before its travel delay indicates an incorrect distributed-history update.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
