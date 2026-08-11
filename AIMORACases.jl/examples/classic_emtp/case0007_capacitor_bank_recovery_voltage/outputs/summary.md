# Classic Case 0007 — Capacitor Recovery Voltage

- `case_id`: classic_case0007_capacitor_bank_recovery_voltage
- `input`: examples/classic_emtp/case0007_capacitor_bank_recovery_voltage/case0007.deck
- `calculation`: fixed-step EMT transient
- `julia_only`: true
- `deck_timestep_s`: 5.0e-5
- `deck_requested_duration_s`: 0.05
- `plotted_duration_s`: 0.05
- `recorded_samples`: 1001
- `nodes`: 10
- `output_channels`: 13
- `maximum_absolute_voltage_pu`: 1.5150387737428108
- `maximum_absolute_output_pu`: 2.5150365804555532
- `interpretation`: Opening the three bank switches at 1 ms traps capacitor charge while the source continues at 60 Hz, creating switch recovery voltage.
