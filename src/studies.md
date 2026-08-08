# Studies and Models

A physical asset has one identity, topology, rating, and provenance. Each study adds a typed parameter facet, analogous to study tabs in commercial power-system tools:

| Shared asset | Power flow facet | Short-circuit facet | EMT facet |
|---|---|---|---|
| terminals, ratings, status | steady-state impedance and controls | sequence data and grounding | geometry, frequency dependence, dynamic state |

A study validates only the information it requires. Detailed data may produce a simpler representation only through a documented conversion; missing detailed parameters are never silently invented.

## Modern EMT 1.0 converter slice

The named Modern EMT 1.0 slice contains one Julia-owned three-phase, three-wire, switch-detailed two-level VSC. Six generic IGBT positions and ideal zero-recovery antiparallel diodes couple a floating dynamic DC link to a grounded-wye grid through one series L-filter and transformer-leakage arrangement. A finite two-terminal DC source makes DC mean voltage and ripple calculated outputs rather than imposed waveforms.

The released control family is a known-angle synchronous-reference-frame grid-following current PI controller with exact sample, computational-delay, zero-order-hold, and trailing-edge PWM calendars. Both sinusoidal PWM and minimum-maximum zero-sequence-injected PWM duty formulations are public; the latter is line-voltage-equivalent to centered space-vector PWM in the linear modulation region but is not presented as a separate vector dwell-time sequencer. The canonical case uses a 10 kHz carrier, 100 microsecond controller period, two microsecond control delay, two microsecond commutation dead time, and one microsecond electrical step.

The public validity boundary is `SwitchingDetailed`, 45–65 Hz, 320–440 V line-to-line RMS, 650–900 V DC source, and an electrical timestep no larger than one microsecond, with positive finite ratings, filter/DC-link values, source resistances, and current limit. Fault, block, clearance, restart, control, carrier, gate, and analysis-window times must lie on the declared scheduler calendar. The public generic catalog entry is an exact synthetic case input, not a measured product or statistical estimate.

Typed results include pole and line voltages, phase/filter currents, DC-link voltage and source current, P/Q, six gate states, forward and antiparallel-diode conduction states, semiconductor/resistive loss, stored energy, external power, separately integrated DC-source and AC-terminal energies, whole-network and DC-to-AC residuals, KCL residual, protection state, exact event and commutation occurrences, and harmonic metadata. The canonical public study exercises sag, a prescribed source-side phase-to-ground voltage collapse, converter block, fault clearance, and restart; private qualification isolates the line-voltage RMS and THD effects of declared dead time against an otherwise identical zero-dead-time run.

This slice does not claim PLL dynamics, grid-forming control, four-wire zero-sequence current, LCL resonance, transformer magnetization or saturation, semiconductor reverse recovery, nonlinear device capacitance, switching-energy maps, electrothermal state, manufacturer prediction, adaptive global timesteps, standard conformance, or certification. Other converter topologies, control families, plant models, and compliance domains require separate qualification.

The implementation evidence revision is engine `c77c37e042362a42b390a127552f59c82c74f5a2`, private solver `864b4a2f9defa71c7b9f6468957b031bb9c43d8e`, public case `9e2d3cbb0fb73e04eeb63457054d8074b61846b8`, generic catalog `07222ae077d04efc618c605a652e972d84232d7c`, independent reference models `7003467c054a740786734c39cc83139d178247b6`, and private qualification `636c39389bbb22286c6c5a6212af11a187d404b8`. The private workspace ledger owns the final release-gate and acceptance revision; this public page does not expose private evidence artifacts.

## Current maturity

| Study | Status | Availability |
|---|---|---|
| EMT | Implemented for the named BPA regression and Modern EMT 1.0 sets | Authorized full engine |
| Line constants | Implemented | Authorized full engine |
| Cable constants | Implemented | Authorized full engine |
| Power flow | Planned contract | Not yet implemented |
| Short circuit | Planned contract | Not yet implemented |
| Protection | Planned contract | Not yet implemented |
| Arc flash | Planned contract | Not yet implemented |

New studies extend shared catalog and orchestration interfaces rather than accumulating in one solver/catalog file.
