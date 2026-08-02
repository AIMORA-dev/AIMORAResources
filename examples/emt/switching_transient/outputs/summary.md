# Timed Switching Transient

- `case_id`: emt_switching_transient
- `input`: examples/emt/switching_transient/switching_transient.deck
- `julia_only`: true
- `timestep_s`: 2.0e-5
- `duration_s`: 0.0001
- `samples`: 6
- `nodes`: 3
- `output_channels`: 2
- `maximum_absolute_voltage_pu`: 0.999999999999995
- `interpretation`: The BUS2–BUS3 tie closes at 40 microseconds, changing the solved topology and energizing the downstream load.
