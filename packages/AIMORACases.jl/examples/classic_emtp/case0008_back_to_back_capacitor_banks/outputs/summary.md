# Classic Case 0008 — Back-to-Back Capacitor Banks

- `case_id`: classic_case0008_back_to_back_capacitor_banks
- `input`: examples/classic_emtp/case0008_back_to_back_capacitor_banks/case0008.deck
- `calculation`: fixed-step EMT transient
- `julia_only`: true
- `deck_timestep_s`: 1.0e-5
- `deck_requested_duration_s`: 0.04
- `plotted_duration_s`: 0.04
- `recorded_samples`: 2001
- `nodes`: 20
- `output_channels`: 21
- `maximum_absolute_voltage_pu`: 1.4574550819412782
- `maximum_absolute_output_pu`: 1.4574550819412782
- `interpretation`: The first bank closes at 0.5 ms and the second at 17.2 ms; the current-limiting reactors bound the high-frequency exchange between banks.
