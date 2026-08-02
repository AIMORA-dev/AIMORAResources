# Generated IEEE 13-Node-Style Deck

This example demonstrates AIMORA's readable section-based deck syntax on a
small feeder with IEEE 13-node-style bus names. It parses the network, validates
the resulting model, exports bus and element tables, and runs a short Julia EMT
trajectory.

## Run

```bash
make run
```

## Inputs

`ieee13_minimum_core.deck` contains buses, sinusoidal and current sources,
resistive/inductive/capacitive branches, loads, and switches. It is an
educational AIMORA input, not a claim of full electrical equivalence to the
published IEEE 13-node feeder.

## Model, units, and assumptions

The deck uses per-unit source and current amplitudes, branch resistance in ohms, inductance in henries, capacitance in farads, frequency in hertz, and event time in seconds. The Julia run uses a 20 µs timestep through 100 µs. The 60 Hz source is nearly ideal through a large Thevenin conductance. The named `xfmr` row is a resistive teaching link rather than a full transformer, and the feeder omits the published regulator, detailed phase matrices, and full load models.

## Outputs

- `ieee13_parser_summary.json`: parsed node and element counts.
- `ieee13_buses.csv`: bus asset table.
- `ieee13_elements.csv`: EMT element table.
- `ieee13_timeseries.csv`: simulated node voltages.
- `ieee13_waveforms.svg`: selected feeder voltages versus time.

The near-ideal source holds bus 650 close to its prescribed waveform. Downstream
voltages reflect branch drops, loads, the current injection, and the timed
switch event.

## Interpretation

First use the parser summary and exported tables to confirm that every intended asset entered the typed model. Then inspect bus 645 around 40 µs to see the timed switch alter connectivity. The short window demonstrates intake and event routing rather than a settled 60 Hz operating point; downstream voltage differences are therefore topology demonstrations, not feeder benchmark errors.
