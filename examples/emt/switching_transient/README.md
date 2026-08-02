# Timed Switching Transient

This example demonstrates a scheduled topology change in the production Julia
EMT loop. A normally open tie switch closes between two buses.

## Model, units, and assumptions

The fixed-card case advances from 0 to 100 µs with a 20 µs step. Source and reported voltages are per unit, branch resistances are in the deck's electrical resistance units, and event times are seconds. BUS1 feeds BUS2, BUS3 has its own shunt load, and the BUS2–BUS3 tie changes from open to closed at 40 µs. The network is deliberately resistive, so the trace isolates topology admission without stored-energy oscillation or breaker arc physics.

## Run

```bash
make run
```

## Outputs

- `switching_transient_timeseries.csv`: bus and requested branch channels.
- `switching_transient_waveforms.svg`: voltages around the switching instant.
- `summary.md`: timing and peak-value overview.

Look at the samples immediately before and after 40 microseconds. The
downstream bus changes only after the switch is admitted into the nodal
admittance matrix.

## Interpretation

Compare the samples at 20, 40, and 60 µs. The pre-event solution must reflect two disconnected loaded buses; the first accepted post-event solution must reflect the new coupled conductance matrix. The event should appear on a deterministic sample boundary with no anticipatory BUS3 change. This is the smallest example for understanding timed switch mutation order.
