# Classic Case 0011 — Transmission-Line Reclosing

- `case_id`: classic_case0011_transmission_line_reclosing
- `input`: examples/classic_emtp/case0011_transmission_line_reclosing/case0011.deck
- `calculation`: fixed-step EMT transient
- `julia_only`: true
- `deck_timestep_s`: 3.33e-5
- `deck_requested_duration_s`: 0.08
- `plotted_duration_s`: 0.0799866
- `recorded_samples`: 1202
- `nodes`: 25
- `output_channels`: 10
- `maximum_absolute_voltage_pu`: 581677.1813108107
- `maximum_absolute_output_pu`: 581677.1813108107
- `interpretation`: A receiving-end fault and 20 ms breaker opening leave trapped charge on the distributed line, which controls the subsequent terminal recovery waveform.
