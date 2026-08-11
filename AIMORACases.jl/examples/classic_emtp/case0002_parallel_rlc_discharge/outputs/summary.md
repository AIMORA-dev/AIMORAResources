# Classic Case 0002 — Parallel RLC Discharge

- `case_id`: classic_case0002_parallel_rlc_discharge
- `input`: examples/classic_emtp/case0002_parallel_rlc_discharge/case0002.deck
- `calculation`: fixed-step EMT transient
- `julia_only`: true
- `deck_timestep_s`: 1.0e-5
- `deck_requested_duration_s`: 0.01
- `plotted_duration_s`: 0.01
- `recorded_samples`: 1001
- `nodes`: 2
- `output_channels`: 1
- `maximum_absolute_voltage_pu`: 1.0
- `maximum_absolute_output_pu`: 1.0
- `interpretation`: Closing the switch releases the capacitor's initial energy into the parallel resistance and inductance, producing a damped discharge.
