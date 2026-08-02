# Classic Case 0009 — Capacitor-Switch Restrike

- `case_id`: classic_case0009_capacitor_restrike
- `input`: examples/classic_emtp/case0009_capacitor_restrike/case0009.deck
- `calculation`: fixed-step EMT transient
- `julia_only`: true
- `deck_timestep_s`: 1.0e-5
- `deck_requested_duration_s`: 1.2
- `plotted_duration_s`: 1.0
- `recorded_samples`: 2001
- `nodes`: 20
- `output_channels`: 22
- `maximum_absolute_voltage_pu`: 1.9555567301396397
- `maximum_absolute_output_pu`: 2.954679560238498
- `interpretation`: The phase-A interruption and 11.1 ms restrike create a steep recovery transient while the other phases remain energized.
