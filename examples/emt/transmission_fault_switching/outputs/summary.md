# Three-Phase Transmission Fault and Breaker Sequence

- `case_id`: emt_transmission_fault_switching
- `input`: examples/emt/transmission_fault_switching/transmission_fault_switching.deck
- `julia_only`: true
- `timestep_s`: 3.33e-5
- `duration_s`: 0.00999
- `samples`: 301
- `nodes`: 25
- `output_channels`: 10
- `maximum_absolute_voltage_pu`: 2.3102672341055916e10
- `interpretation`: The declared 10 ms horizon records the initial faulted response; the 20 ms breaker opening and 96 ms fault clearing are parsed schedules outside this run.
