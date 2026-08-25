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

This original slice does not retroactively gain PLL dynamics, grid-forming control, four-wire zero-sequence current, LCL resonance, transformer magnetization or saturation, semiconductor reverse recovery, nonlinear device capacitance, switching-energy maps or electrothermal state. Those mechanisms and the separately bounded extended converter families are qualified through their own explicit owners and public matrices; manufacturer prediction, adaptive switching timesteps, protected-standard conformance and certification remain unsupported.

## Extended converter-system library

The separately qualified extended library exposes 22 AC/DC, DC/DC, DC/AC, multilevel and direct AC/AC families across exactly 52 executable standalone family/fidelity intersections plus five average-value application compositions. The [Extended Converter Systems](extended-converter-systems.md) chapter defines the selection, equations, state, event, fidelity, result, evidence and limitation boundary and links the runnable public case.

## Current maturity

| Study | Status | Availability |
|---|---|---|
| EMT | Implemented for the named BPA regression, Modern EMT 1.0, and separately accepted bounded EMT capability sets | Authorized full engine |
| Line constants | Implemented | Authorized full engine |
| Cable constants | Implemented | Authorized full engine |
| Power flow | Planned contract | Not yet implemented |
| Short circuit | Planned contract | Not yet implemented |
| Protection | Planned contract | Not yet implemented |
| Arc flash | Planned contract | Not yet implemented |

New studies extend shared catalog and orchestration interfaces rather than accumulating in one solver/catalog file.
