# Standalone Grid-Following Inverter

This dependency-light example exercises AIMORA's open Julia inverter model
without constructing a full network deck. It is the quickest introduction to a
stateful fixed-step model.

## Model, units, and assumptions

The Julia model is an average-value grid-following inverter with stateful current control and reported terminal active/reactive power. Time is seconds, the fixed step is 20 µs, the run lasts 150 ms, and electrical channels are per unit on the model base. It assumes a prescribed grid terminal, balanced fundamental-frequency behavior, and ideal averaged conversion; semiconductor switching, PWM harmonics, dead time, thermal behavior, and a detailed DC link are outside this introductory example.

## Run

```bash
make run
```

## Outputs

- `inverter_timeseries.csv`: time, terminal voltage/current, and P/Q channels.
- `inverter_power.svg`: active and reactive power waveform.
- `inverter_current.svg`: current waveform.
- `summary.json`: final values and runtime.

The active-power reference changes during the run. The current controller and
reported P/Q should transition smoothly rather than jump instantaneously.

## Interpretation

Use the current plot to see the controller state respond to the reference transition and the power plot to check the direction and settling of P and Q. A finite transition is expected because the current command is dynamic. This demonstrates the public state-update API; it is not yet a switch-detailed converter or grid-fault benchmark.
