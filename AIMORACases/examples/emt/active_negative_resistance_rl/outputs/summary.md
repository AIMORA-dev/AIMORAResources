# Finite Active Negative-Resistance R–L Branch

- `case_id`: emt_active_negative_resistance_rl
- `input`: examples/emt/active_negative_resistance_rl/active_negative_resistance_rl.deck
- `julia_only`: true
- `timestep_s`: 0.0001
- `duration_s`: 0.001
- `samples`: 11
- `nodes`: 2
- `output_channels`: 4
- `maximum_absolute_voltage_pu`: 99.9999999999984
- `interpretation`: The negative physical resistance is accepted because the trapezoidal R–L companion denominator remains finite and nonsingular, producing a bounded Julia waveform.
