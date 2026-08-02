# TACS Network Feedback

- `case_id`: emt_control_network_feedback
- `input`: examples/emt/control_network_feedback/control_network_feedback.deck
- `julia_only`: true
- `timestep_s`: 5.0e-5
- `duration_s`: 0.00030000000000000003
- `samples`: 7
- `nodes`: 6
- `output_channels`: 13
- `maximum_absolute_voltage_pu`: 10.0
- `interpretation`: The sensed network voltage, first-order filter, controlled sources, and switch mutate in the Julia timestep order and produce finite closed-loop channels.
