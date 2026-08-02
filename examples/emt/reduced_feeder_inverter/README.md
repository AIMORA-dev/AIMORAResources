# Reduced Feeder with Inverter

This example couples the open inverter model to a reduced two-node feeder and
compares four operating points in Julia: baseline, light load, heavy load, and
a larger reactive-power command. The companion `unified_emt` example shows one
compact high-level run; this example focuses on parameter sensitivity and the
boundary of the reduced network model.

## Model and assumptions

The feeder is a Thevenin source behind a series R-L branch. At the load bus,
the scalar nodal balance is

\[
G_{load}v_{bus}+i_{RL}-i_{inv}=0,
\qquad
i_{inv}=\frac{P_{inv}}{\max(|v_{bus}|,0.2)}.
\]

The baseline uses a 20 µs timestep, 0.15 s duration, 0.843 pu load
conductance, and an active-power command that rises from 0.35 to 0.80 pu. The
prototype reports inverter reactive power but does not inject it into the
scalar network equation. The reactive-command comparison makes that limitation
visible instead of hiding it.

## Run

```bash
make run
```

## Outputs

- `reduced_feeder_timeseries.csv`: network and inverter channels.
- `reduced_feeder_voltage.svg`: feeder voltage waveform.
- `reduced_feeder_inverter_power.svg`: inverter P/Q waveform.
- `operating_point_metrics.csv`: final voltage and P/Q for all four scenarios.
- `operating_point_voltage.svg`: comparative bus-voltage waveforms.
- `summary.json`: deterministic baseline configuration and final values.
- `summary.md`: scenario checks and model-boundary interpretation.

The light-load voltage must exceed the heavy-load voltage. The baseline and
reactive-command bus voltages are equal because this educational prototype
couples only active current into the network; their reported Q trajectories are
different.
