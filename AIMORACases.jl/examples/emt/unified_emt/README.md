# Unified EMT Workflow

This example presents the same reduced feeder/inverter model as one compact
high-level AIMORA workflow. It is intended for users who want to configure and
run a study before learning individual nodal stamps.

## Model, units, and assumptions

`UnifiedEMTConfig` runs a reduced feeder coupled to the public average-value inverter for 150 ms with a 20 µs step. Voltage, active power, and reactive power are per unit; time is seconds. The initial bus target is 0.972 pu, active-power reference moves from 0.35 to 0.80 pu, and reactive reference is 0.05 pu. The feeder is a compact equivalent and the converter omits semiconductor switching, PWM harmonics, unbalance, and detailed protection.

## Run

```bash
make run
```

## Outputs

- `unified_emt_timeseries.csv`: complete sampled trajectory.
- `unified_voltage.svg`: bus-voltage waveform.
- `unified_power.svg`: inverter active/reactive power.
- `summary.json`: inputs, final values, and runtime.

Start here for the high-level API; compare with `nonlinear_controls` or
`line_models` when you need lower-level model composition.

## Interpretation

The voltage plot shows how the reduced feeder responds as inverter power changes, while the power plot exposes controller settling and the P/Q sign convention. The summary records final values and runtime so configuration changes are easy to compare. Use this example to learn orchestration; use switch-detailed or phase-domain cases when those effects matter scientifically.
