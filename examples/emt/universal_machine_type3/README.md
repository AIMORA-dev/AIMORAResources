# Universal Machine Type 3

This example runs a three-phase induction-machine case through AIMORA's
universal-machine deck intake, initialization, network coupling, and reporting
path.

## Model, units, and assumptions

Universal-machine type 3 represents a three-phase induction machine with one shorted rotor coil on each d/q axis. The deck uses a 60 Hz electrical base, automatic steady-state initialization, a 200 µs timestep, and a 100 ms horizon. Terminal sources and machine tables retain their declared engineering/base conventions; public traces are reported in per unit and time in seconds. The example includes a simple mechanical network and torque measurement but not saturation, thermal behavior, or a detailed driven load.

## Run

```bash
make run
```

## Outputs

- `universal_machine_type3_timeseries.csv`: terminal, network, and requested
  machine channels.
- `universal_machine_type3_waveforms.svg`: selected machine outputs.
- `summary.md`: timestep, duration, nodes, channels, and peak voltage.

The waveform connects the machine's electrical terminal behavior to its
evolving internal/mechanical state. Use `machine_tacs_interface` for a focused
control-signal transfer example.

## Interpretation

Inspect all CSV channels together: terminal voltage/current, rotor/electromagnetic quantities, and mechanical state must advance on the same timeline after initialization. Balanced terminal channels should retain their phase relationship while rotor speed and torque evolve consistently with the applied mechanical network. This direct type-3 example is the entry point; the machine-type gallery compares all supported type variants and initialization modes.
