# Signed Source and Control Routing

- `case_id`: emt_signed_source_routing
- `input`: examples/emt/signed_source_routing/signed_source_routing.deck
- `julia_only`: true
- `timestep_s`: 5.0e-5
- `duration_s`: 0.00030000000000000003
- `samples`: 7
- `nodes`: 6
- `output_channels`: 13
- `maximum_absolute_voltage_pu`: 10.0
- `interpretation`: Negative routing identifiers preserve electrical orientation while AIMORA selects the source model by its absolute type and executes the TACS feedback path.
