# Reduced-Feeder Inverter Sensitivity

- `julia_only`: true
- `scenario_count`: 4
- `timestep_s`: 2.0e-5
- `duration_s`: 0.15
- `light_load_voltage_exceeds_heavy_load`: true
- `reactive_power_affects_network_voltage`: false
- `interpretation`: Load conductance changes the solved bus voltage; reactive power is reported but intentionally does not enter this reduced scalar current injection.
