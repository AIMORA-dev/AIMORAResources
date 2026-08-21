# Study Reference

The study catalogue is an availability contract. `implemented` means an executable public study workflow exists at the referenced revision. `planned` means AIMORA exposes a design or future API boundary but must refuse production execution. This reference mirrors the public `StudyCatalog` without turning roadmap entries into product claims.

## Implemented studies

| Study ID | Engineering purpose | Typical products |
| --- | --- | --- |
| `emt` | Instantaneous electromagnetic-transient simulation with topology events, nonlinear devices, controls, machines, lines, restart, and reporting | time series, event traces, energy/KCL diagnostics, checkpoint, CSV, SVG, semantic report |
| `line_constants` | Overhead-line impedance, admittance, sequence/modal quantities, and frequency response from geometry and material data | Z/Y matrices, sequence constants, modal data, frequency curves, engineering report |
| `cable_constants` | Cable/sheath/screen impedance, admittance, modal quantities, and frequency scans | conductor/sheath matrices, modal results, frequency curves, construction report |
| `transformer_parameters` | Conversion of nameplate/test/design data into transformer branch and coupling parameters | parameter tables, generated branch data, test reconciliation, uncertainty/limitations report |

## Planned static, network, and planning studies

| Study ID | Name | Status |
| --- | --- | --- |
| `power_flow` | AC balanced power flow | planned |
| `unbalanced_power_flow` | AC unbalanced multiphase power flow | planned |
| `dc_power_flow` | DC power flow | planned |
| `voltage_drop` | Voltage-drop calculation | planned |
| `load_allocation` | Load allocation | planned |
| `load_growth` | Load growth and planning | planned |
| `contingency` | Contingency and N-1 screening | planned |
| `voltage_stability` | Voltage-stability margin | planned |
| `hosting_capacity` | DER hosting capacity | planned |
| `optimal_power_flow` | Optimal power flow | planned |

## Planned fault and protection studies

| Study ID | Name | Status |
| --- | --- | --- |
| `short_circuit` | General short-circuit study | planned |
| `iec_short_circuit` | IEC-style short circuit | planned |
| `ansi_short_circuit` | ANSI-style short circuit | planned |
| `unbalanced_fault` | Unbalanced fault analysis | planned |
| `dc_short_circuit` | DC short circuit | planned |
| `protection` | Protection coordination | planned |
| `relay_settings` | Relay-setting calculation | planned |
| `time_current_coordination` | Time-current coordination | planned |
| `fuse_recloser_coordination` | Fuse/recloser coordination | planned |
| `distance_protection` | Distance protection | planned |
| `differential_protection` | Differential protection | planned |
| `protection_optimization` | Protection-setting optimization | planned |

## Planned safety, grounding, and insulation studies

| Study ID | Name | Status |
| --- | --- | --- |
| `arc_flash` | Arc-flash calculation | planned |
| `arc_flash_labels` | Arc-flash label generation | planned |
| `grounding_grid` | Grounding-grid design | planned |
| `step_touch_voltage` | Step and touch voltage | planned |
| `grounding_conductor_sizing` | Grounding-conductor sizing | planned |
| `lightning_surge_risk` | Lightning and surge-risk screening | planned |
| `insulation_coordination` | Insulation coordination | planned |

## Planned dynamic and transient studies

| Study ID | Name | Status |
| --- | --- | --- |
| `rms_transient_stability` | RMS transient stability | planned |
| `switching_transients` | Switching-transient workflow | planned; detailed phenomena may currently be studied only through explicit EMT cases |
| `lightning_transients` | Lightning and surge-transient workflow | planned; explicit EMT cases remain case-specific |
| `transformer_inrush` | Transformer energization and inrush workflow | planned; explicit EMT apparatus cases remain model-specific |
| `motor_starting_dynamic` | Dynamic motor starting | planned |
| `ferroresonance` | Ferroresonance workflow | planned; public EMT examples do not constitute a general study API |

## Planned power-quality studies

| Study ID | Name | Status |
| --- | --- | --- |
| `harmonic_load_flow` | Harmonic load flow | planned |
| `harmonic_resonance` | Harmonic resonance | planned |
| `filter_sizing` | Harmonic-filter sizing | planned |
| `flicker` | Flicker | planned |
| `voltage_sag_swell` | Voltage sag and swell | planned |
| `voltage_unbalance` | Voltage unbalance | planned |

## Planned machine studies

| Study ID | Name | Status |
| --- | --- | --- |
| `induction_machine` | Induction-machine study | planned; machine models may be executable inside admitted EMT cases |
| `synchronous_machine` | Synchronous-machine study | planned; machine models may be executable inside admitted EMT cases |
| `generator_capability` | Generator capability/loading | planned |
| `motor_torque_speed` | Motor torque-speed checks | planned |
| `machine_thermal` | Machine thermal loading | planned |
| `excitation_governor` | Excitation and governor workflow | planned; sampled controls may be executable inside admitted EMT cases |

## Planned renewable, converter, and storage studies

| Study ID | Name | Status |
| --- | --- | --- |
| `pv_string_sizing` | PV string sizing | planned |
| `pv_inverter_sizing` | PV inverter sizing | planned |
| `pv_cable_sizing` | PV DC/AC cable sizing | planned |
| `pv_yield` | PV yield and clipping | planned |
| `grid_following_inverter` | Grid-following inverter workflow | planned; open component prototypes do not prove a network study |
| `grid_forming_inverter` | Grid-forming inverter workflow | planned |
| `bess_sizing` | Battery-energy-storage sizing | planned |
| `storage_dispatch` | Storage dispatch | planned |
| `wind_turbine` | Wind-turbine study | planned |
| `ride_through` | Ride-through compliance | planned |

## Planned cable, conductor, and equipment sizing studies

| Study ID | Name | Status |
| --- | --- | --- |
| `cable_ampacity` | Cable ampacity | planned |
| `dynamic_cable_rating` | Dynamic cable thermal rating | planned |
| `cable_thermal_capacity` | Cable thermal overload capacity | planned |
| `cable_short_circuit_withstand` | Cable short-circuit withstand | planned |
| `cable_pulling` | Cable pulling and tension | planned |
| `duct_bank_derating` | Duct-bank/tray derating | planned |
| `sheath_bonding` | Cable sheath bonding/circulating current | planned |
| `conductor_sizing` | Conductor sizing | planned |
| `transformer_sizing` | Transformer sizing | planned |
| `generator_sizing` | Generator sizing | planned |
| `motor_sizing` | Motor sizing | planned |
| `switchgear_rating` | Switchgear rating | planned |
| `ct_vt_sizing` | CT/VT sizing | planned |
| `ups_battery_sizing` | UPS and battery sizing | planned |

## Planned optimization, reliability, and asset studies

| Study ID | Name | Status |
| --- | --- | --- |
| `feeder_reconfiguration` | Feeder reconfiguration | planned |
| `capacitor_placement` | Capacitor-placement optimization | planned |
| `der_placement_sizing` | DER placement and sizing | planned |
| `cable_sizing_optimization` | Cable-sizing optimization | planned |
| `reliability_indices` | Reliability indices | planned |
| `outage_impact` | Outage impact | planned |
| `asset_aging` | Asset loading and aging | planned |
| `transformer_loss_of_life` | Transformer loss of life | planned |
| `cable_thermal_aging` | Cable thermal aging | planned |

## Common execution contract

Every implemented study must expose:

- strict typed inputs and readiness diagnostics;
- project/scenario/study identity;
- representation and fidelity;
- explicit settings, tolerances, units, bases, assumptions, and validity domain;
- selected solver capability and revision;
- immutable typed result with content hash;
- warnings and unsupported behavior;
- public case and report provider;
- independent qualification evidence appropriate to the claim.

## EMT study workflow

1. Parse and validate the deck/project.
2. Confirm all component and solver capabilities.
3. Establish a consistent initial state or declare accepted initial discontinuities.
4. Execute fixed-step/network/control/event schedules.
5. Localize discontinuities and preserve rollback/checkpoint state.
6. Produce typed traces and diagnostics.
7. Check finite values, KCL, energy, passivity, timestep refinement, and exact restart as applicable.

## Line and cable constants workflow

1. Validate geometry, materials, units, conductor ordering, earth data, and frequency grid.
2. Build primitive impedance/admittance matrices.
3. Reduce or transform only through declared conductor/bonding rules.
4. Compute sequence/modal quantities where mathematically admitted.
5. Report conditioning, symmetry/passivity, frequency range, and transformation conventions.

## Transformer-parameter workflow

1. Validate ratings, winding order, connection, test data, bases, and units.
2. Reconcile test values and convert to a single declared convention.
3. Generate branch/coupling parameters.
4. Report residuals, assumptions, uncertainty, and data that cannot be inferred.
