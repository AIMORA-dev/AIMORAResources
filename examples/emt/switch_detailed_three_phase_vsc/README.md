# Switch-Detailed Three-Phase Two-Level VSC

This Julia-only case runs one complete three-phase, three-wire, switch-detailed two-level voltage-source converter. Six generic IGBT positions and their ideal zero-recovery antiparallel diodes couple a floating 800 V DC link to a grounded-wye 400 V grid through three series filter and transformer-leakage branches. The DC capacitor is supplied through a finite two-terminal Thevenin resistance, so its mean voltage and switching ripple are physical outputs rather than imposed waveforms. Parameters are synthetic, redistributable, and tied to the matching generic catalog entry; they do not describe or certify a manufacturer product.

The control family is a known-angle synchronous-reference-frame grid-following current PI regulator. It samples every 100 microseconds, releases each command after a two-microsecond computational delay, and drives exact trailing-edge minimum-maximum zero-sequence-injected PWM at 10 kHz. This carrier formulation is line-voltage-equivalent to centered space-vector PWM in its linear modulation region; it does not claim a separate vector dwell-time sequencer. This case deliberately does not claim phase-locked-loop dynamics. The one-microsecond electrical step resolves commutation dead time, gate edges, natural diode paths, DC-link dynamics, line/pole waveforms, terminal current, power, loss, stored energy, and reversible topology state.

The 60 ms scenario includes a balanced grid sag, a prescribed source-side phase-to-ground voltage collapse, converter blocking during the fault, fault clearance, and controlled restart. The final 20 ms window is one exact 50 Hz cycle used for P/Q and harmonic measurements. Positive phase current and active power flow from converter to grid. The transformer is an ideal grounded-wye ratio with leakage referred to the converter side; magnetizing current, saturation, and four-wire zero-sequence current are outside the released model.

## Run

```bash
make run
```

## Outputs

- `three_phase_vsc_waveforms.csv` records a deterministic bounded view of DC voltage, P/Q, phase currents, line voltages, and block state.
- `three_phase_vsc_device_states.csv` records phase duties, six applied gates, and active antiparallel-diode counts.
- `three_phase_vsc_currents.svg` shows the three filter currents across the sag, fault, block, clearance, restart, and final regulation interval.
- `three_phase_vsc_dc_link.svg` shows the dynamic DC-link response and post-event ripple.
- `summary.md` reports control/PWM counts, P/Q tracking, DC ripple, THD metadata, zero-sequence rejection, KCL, separately integrated DC-source/AC-terminal energy balance, commutations, protection events, exact alignment, fidelity, and limitations.

Interpret the final cycle as the regulation and harmonic acceptance window, not the fault interval. The active-power mean should remain within three percent of 20 kW, mean reactive power within 500 var of zero, DC ripple below 5 V, phase-current THD below five percent, line-voltage THD below three percent, zero-sequence current below 0.1 microampere, KCL residual below 0.1 microampere, and both whole-network and separately integrated DC-to-AC relative energy residuals below `1e-5`. The case must also show all-off dead-time samples, natural diode conduction, one block and restart, six exact disturbance/protection boundaries, finite output, and no shoot-through. Private qualification isolates and bounds dead-time waveform distortion against an otherwise identical zero-dead-time execution. Unsupported behavior includes PLL and grid-forming dynamics, LCL resonance, transformer magnetization/saturation, semiconductor reverse recovery and nonlinear capacitance, switching-energy maps, electrothermal state, manufacturer prediction, standard conformance, and certification.
