# Extended VSC Controls and Filters

AIMORA extends its carrier-switching-detailed two-level voltage-source converter with four controller families, three passive-filter families, and three- or four-wire network forms. Every selection executes the same B200 bridge and compatible D200 devices through the normal instantaneous-EMT network, task, event, transaction, initialization, checkpoint, and result owners. The established known-angle three-wire L-filter model remains available as a separate compatibility family.

## Selection matrix

The controller choices are synchronous PLL-dq grid following, stationary proportional-resonant grid following, active-power/frequency plus reactive-power/voltage droop grid forming, and virtual-synchronous grid forming with virtual inertia, damping, impedance, and filtered virtual current. Each controller is admitted with series L, shunt LC, or LCL filtering and with either three- or four-wire connection, for 24 explicit supported combinations.

Three-wire systems constrain zero-sequence current and refuse a source scenario that requests nonzero zero-sequence voltage. Four-wire systems add the fourth bridge leg, neutral R-L state, grid neutral, neutral grounding, and explicit phase-to-neutral and neutral-current reporting. One accepted combination does not qualify another combination or another converter topology.

## Frames, signs, and controller state

The public transforms use amplitude-invariant Clarke components and synchronous Park components. AC terminal current is positive from converter toward the grid, DC current is positive from source into the converter, and active power is positive from DC to AC. Instantaneous active and reactive power include the declared zero-sequence contribution.

The PLL-dq family owns angle, frequency, normalized quadrature-voltage error, PI state, lock status, voltage-loss behavior, current-loop integral state, and anti-windup. The stationary PR family owns the PLL state plus independently sampled alpha/beta resonator states for each selected harmonic. The droop family owns filtered active/reactive power, angle, frequency, voltage reference, voltage-loop state, current limiting, and anti-windup. The virtual-synchronous family adds swing-equation frequency and angle, virtual impedance, filtered virtual current, and the same bounded modulation interface.

All sampled controller state is mutated only at the exact declared control task. PWM releases its delayed command at exact scheduler boundaries. A failed electrical trial restores controller, task, event, bridge, device, filter, neutral, energy, and recorder state atomically.

## Filters and initialization

The series-L family contains converter-side R-L state. The shunt-LC family adds a shunt capacitor and positive damping conductance at the filter terminal. The LCL family adds a grid-side R-L branch around the same damped shunt capacitor. Four-wire forms additionally own a neutral R-L path.

Every resistance is nonnegative, every selected inductance and capacitance is positive, damping must be passive, and the controller sample rate must remain compatible with the filter resonance. Accepted initialization establishes DC-link, filter, capacitor, neutral, grid-source, device, task, and controller histories at `t = 0`; it does not hide an unreported settling run.

## Plant requests, limiting, and protection

A plant request is an immutable timestamped value containing available active power, active/reactive or voltage/frequency targets, ramp bounds, current priority, uncertainty/provenance, and a validity interval. The exact dispatch task samples it. The result distinguishes applied, limited, stale, and refused requests.

Current limiting supports active-current, reactive-current, and vector-magnitude priority. Saturated PI or resonant commands use explicit anti-windup. Generic protection monitors AC/filter current, DC voltage, PLL voltage loss for grid-following operation, frequency/voltage limits for grid-forming operation, and explicit block requests with debounce, latching, restart readiness, and delays. These thresholds are generic parameters—not IEEE, IEC, vendor, or grid-code settings.

The public disturbance contract covers balanced sag, phase angle/frequency changes, negative sequence, selected source harmonics, phase-ground, phase-phase and balanced voltage-collapse faults, DC-source sag, current limiting, block/restart, and applicable island/reconnection. Four-wire cases also admit zero sequence and neutral operation. Destructive device failure and arc physics are outside this model.

## Results and adequacy

`ExtendedVSCTrace` retains time, pole/filter/grid voltages, converter/grid/neutral currents, DC-link voltage, active/reactive power, positive/negative/zero sequence magnitude, controller frequency, duty, mode, plant-request disposition, stored energy, dissipated and external power, companion-method residual, nodal and nonlinear KCL residual, exact task occurrences, disturbance boundaries, metrics, and a deterministic signature.

Use the model only when the chosen carrier, timestep, controller period/delay, filter resonance, voltage/current/power range, harmonic set, wire form, and device fidelity match the declared study. Inspect KCL, energy, limiter/protection activity, sequence settling, exact task/boundary alignment, and refinement evidence before interpreting a waveform.

## Public cases and evidence boundary

Four public synthetic cases cover the four controller families: `emt_extended_vsc_pll_dq`, `emt_extended_vsc_pr`, `emt_extended_vsc_droop`, and `emt_extended_vsc_virtual_synchronous`. Together they cover L, LC, and LCL filters, three- and four-wire forms, unbalance and zero sequence, plant requests, exact tasks, disturbances, block/restart, typed results, deterministic CSV data, scalar summaries, and curated current and DC/sequence SVG plots. The catalogue entry `extended_vsc_control_filter_platform` records the generic provenance and admitted domain.

Independent Julia formulations check current projection, PLL, PR, power filtering, droop, swing, instantaneous power, sequence extraction, and passive companion energy without importing production VSC or solver code. A pinned OpenModelica/Modelica Standard Library run covers only its named two-level PWM pole voltage and polyphase R-L terminal voltage/current waveforms. It does not validate AIMORA controllers, four-wire behavior, protection, plant requests, ATP/PSCAD behavior, standards, HIL, or certification.

## Exclusions

This platform does not qualify other bridge families; three-level, multipulse, rectifier, DC-DC, FACTS, HVDC, MMC, renewable, storage, or wind plants; detailed transformer magnetization; frequency-dependent lines; arbitrary user controllers; average-value substitution; adaptive/DASSL execution; vendor models; protected-standard conformance; ATP/PSCAD equivalence; HIL; or certification. Later packages may compose this interface, but they must obtain their own evidence and may not broaden these claims silently.
