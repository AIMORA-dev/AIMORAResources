# Nonlinear Devices with TACS Control

This example assembles a source, diode valve, controlled switch, load, and
saturable inductor in one nodal EMT system. A first-order TACS function drives
the switch command.

## Model, units, and assumptions

The run advances ten fixed 20 µs steps. Voltages and currents are per unit, time is seconds, and the TACS command is dimensionless. A nearly ideal 1 pu Thevenin source feeds a threshold diode, a control-operated switch, a 1 pu shunt conductance, and a two-slope saturable inductor. The model is a compact scalar topology demonstration: it omits valve reverse recovery, switching losses, magnetic hysteresis, and a physical controller sensor chain.

## Run

```bash
make run
```

## Outputs

- `nonlinear_controls_trace.csv`: control, voltage, switch states, and current.
- `nonlinear_controls_waveform.svg`: control, load voltage, and nonlinear
  inductor current.

Inspect the CSV around the control threshold. The switch topology and nonlinear
current must be updated in the same accepted timestep sequence.

## Interpretation

Follow the control column until it crosses 0.5, then confirm that the controlled-switch state, load voltage, and inductor current change in the corresponding accepted step. The diode state must still follow its voltage/current rule independently. A one-sample disagreement between command, topology, and solved voltage is evidence of incorrect mutation ordering.
