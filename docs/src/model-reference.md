# Model Library

This chapter explains the engineering role, fidelity, data requirements, state, outputs, selection criteria, and limitations of the AIMORA model families. The generated [Model Declaration Index](generated/model-index.md) enumerates every declaration found under the public engine model owners and records declared fields and exports. Read both pages together: this chapter gives engineering meaning; the generated page provides source-level completeness and traceability.

## Model contract used throughout AIMORA

A supported scientific model should declare or document:

| Contract element | Meaning |
|---|---|
| Identity | Stable model or capability identifier |
| Fidelity | Physical and numerical representation level |
| Inputs | Quantity, unit, base, orientation, provenance, and allowed range |
| Outputs | Quantity, unit, base, orientation, and interpretation |
| State | Differential, algebraic, discrete, delayed-history, scheduler, and random state |
| Validity domain | Bounds and unsupported phenomena |
| Assumptions | Simplifications necessary for use |
| Mutation order | Deterministic update sequence for stateful execution |
| Maturity | Implemented, prototype, planned, or legacy reference |
| Evidence | Tests, reference calculations, cases, and restart/conservation checks |

The engine can assess a request against a model validity domain. A mismatch must produce an explicit violation. It must not silently change the requested fidelity or extrapolate beyond documented bounds.

# Network primitives

## Resistive, inductive, capacitive, and combined branches

Network branches represent lumped two-terminal or coupled impedances and admittances. They are appropriate when propagation delay and frequency-dependent distributed behavior are not material to the study bandwidth.

Typical families include:

- pure resistance;
- pure inductance;
- pure capacitance;
- series R–L;
- series R–L–C;
- shunt conductance/capacitance;
- coupled phase or matrix branches;
- equivalent branches generated from transformer or line-constant studies.

### Required data

- terminal identities and positive current direction;
- resistance in ohms;
- inductance in henries;
- capacitance in farads;
- initial current or capacitor voltage when nonzero;
- coupling matrix and phase ordering for multiphase models;
- base values when data are supplied in per unit.

### Dynamic state

Inductors retain current-related history; capacitors retain voltage/charge-related history. In companion-model EMT execution, these states contribute an equivalent conductance and history source at each timestep. Checkpoint restoration must reproduce both physical state and integration history.

### Outputs

- terminal voltage and branch current;
- instantaneous and averaged power;
- stored magnetic/electric energy;
- dissipated energy for resistive terms;
- local residuals where exposed.

### Limitations

A lumped branch does not represent travelling-wave delay, skin effect, ground-return frequency dependence, modal transformation, corona, distributed geometry, or electromagnetic coupling that was not included in its matrices.

## Independent and equivalent sources

Source models provide prescribed voltage/current excitation or a finite Thevenin/Norton equivalent.

Use an ideal source only when infinite short-circuit strength is intentional. For realistic network interaction, include source impedance or use a finite equivalent.

Document:

- waveform definition and phase reference;
- RMS/peak/instantaneous convention;
- frequency and phase sequence;
- source impedance and grounding;
- energization time and ramp policy;
- whether the source is a physical boundary or a test stimulus.

A prescribed source waveform is not a calculated system response. Reports must keep imposed and solved quantities distinct.

## Ideal constraints

Ideal voltage, current, or topological constraints are useful for controlled numerical experiments but can create singular or overconstrained systems. The model must detect inconsistent constraints, duplicate ideal paths, or unsupported floating islands. An ideal constraint should not be used to hide unavailable physical impedance.

# Switching and event devices

## Timed and controlled switches

Switches change topology according to an event calendar or control signal. Relevant models include ideal switches, finite on/off conductance representations, externally controlled switches, and devices with current-zero opening behavior.

Required data include:

- terminals and normal state;
- close/open times or control source;
- on-state resistance/conductance;
- off-state leakage where represented;
- current-zero, dead-time, or hysteresis policy;
- event priority when simultaneous events occur.

Outputs should expose state, transition time, current, voltage, and any rejected/chattering transition. Event times must be aligned or localized according to the declared scheduler policy.

## Breaker and current-zero behavior

A current-zero opening model must distinguish a requested opening time from the physically executed interruption. It should record the first accepted current zero, polarity, residual current tolerance, and failure to interrupt within the horizon. It is not automatically an arc model or a complete circuit-breaker dielectric-recovery model.

## Delayed-arc and control-coupled switching

Where a switch is coupled to a delayed arc, TACS expression, protection signal, or sampled control task, the state update order is part of the model contract. The report should identify sensing, decision, computational delay, hold, gate command, physical transition, and any blocking or reclose logic separately.

# Nonlinear devices and nonlinear networks

## Exponential and polynomial branches

Nonlinear current–voltage devices may use exponential, polynomial/cubic, piecewise, fitted, or user-defined constitutive laws. They require:

- explicit sign convention;
- units for every coefficient;
- validity interval;
- derivative/Jacobian behavior;
- initial operating point;
- limiting or regularization policy near singular regions.

The nonlinear solver should report convergence, iteration count, residual norm, damping/line-search behavior, and rejection reason.

## Surge arresters and ZnO characteristics

Arrester models represent nonlinear voltage-dependent conduction. Inputs should identify the source of the V–I characteristic, current/voltage convention, interpolation or fit method, temperature/energy limitations when represented, and the frequency range of any dynamic model.

Outputs normally include arrester voltage, current, instantaneous power, absorbed energy, and nonlinear residual. A static V–I curve does not by itself represent thermal failure, aging, lead inductance, housing flashover, or manufacturer certification.

## Hysteretic and magnetic nonlinearities

Hysteretic models retain path-dependent state. Initial branch, remanence, coercive behavior, saturation law, timestep sensitivity, and energy/loss interpretation must be documented. A single-valued saturation curve is not equivalent to a hysteresis loop.

## Nonlinear-network execution

The nonlinear-network layer combines multiple nonlinear devices, ideal constraints, topology changes, and sparse nodal equations. Professional acceptance requires:

- scaled residuals rather than raw values alone;
- deterministic discontinuity localization;
- topology-aware Jacobian updates;
- chatter prevention or explicit chatter reporting;
- rollback after rejected steps/events;
- exact or tolerance-bounded checkpoint replay;
- KCL and energy diagnostics.

# Transmission-line models

A line model must be selected from the study bandwidth, line length, geometry, phase coupling, ground-return behavior, and available data. Do not select a wideband model merely because it is more complex.

## Lumped and cascaded-π lines

Cascaded-π sections approximate distributed behavior with repeated lumped series impedance and shunt admittance. They are useful for lower-frequency studies or when a controlled approximation is acceptable.

Document section count, per-length parameters, total length, frequency at which parameters apply, grounding, and the error criterion used to choose the section count. Excessive sectioning can increase stiffness and cost without resolving missing frequency dependence.

## Bergeron and travelling-wave lines

Bergeron-type models represent propagation delay with characteristic impedance and delayed history. They are appropriate when travel time is material and parameters can be treated as sufficiently constant over the relevant band.

State includes delayed terminal histories and interpolation indices. Required data include line length, propagation velocity/delay, surge impedance, phase/modal transformation, and loss treatment. Checkpoints must preserve the complete delay buffer and scheduler position.

## Modal and phase-domain coupled lines

Multiconductor lines may be solved through modal decomposition or directly in phase domain. Document:

- conductor/phase ordering;
- modal transformation and normalization;
- treatment of frequency-dependent modes;
- complex mode handling;
- conversion between modal and terminal quantities;
- whether transformations are constant or frequency dependent.

Mode swapping, sign ambiguity, or poorly conditioned transformations can corrupt a frequency sweep. Continuity and passivity diagnostics are required.

## Sampled-frequency line models

A sampled-frequency model starts from impedance/admittance or propagation data evaluated at discrete frequencies. Required inputs include sample frequencies, units, reference conductor/ground model, matrix dimensions, and preprocessing policy.

The sample grid must cover the phenomenon bandwidth and include enough low-frequency information to define steady behavior. Extrapolation outside the sampled range must be identified.

## Semlyen and rational frequency-dependent models

Frequency-dependent lines approximate terminal or modal behavior with rational functions and dynamic states. Model construction should document:

- quantity fitted: impedance, admittance, propagation, characteristic admittance, or terminal transfer;
- frequency samples and weighting;
- pole count/order and real/complex pole policy;
- fitting error metric;
- stability enforcement;
- passivity assessment and correction;
- conversion to real state-space execution;
- delay separation where applicable.

Outputs should include fit residuals, passivity margins, corrected/unmodified comparison, pole/residue data, and runtime conservation diagnostics. A low least-squares error is not sufficient if the fit is unstable or non-passive.

## Wideband parameters and runtime state

Wideband models may combine geometry-derived frequency scans, vector fitting, modal tracking, rational states, and explicit delays. Dynamic state includes rational filter states, delayed histories, interpolation state, event state, and checkpoint metadata.

Use wideband models for fast-front, cable, long-line, switching-surge, or other studies where frequency dependence materially affects results. Avoid them when parameter provenance or frequency coverage is inadequate.

## Overhead-line constants

The overhead-line constants model calculates impedance and capacitance/admittance from conductor geometry and material data. Required data include:

- conductor coordinates and phase identity;
- conductor radius/GMR and resistance;
- bundle geometry;
- earth resistivity and ground-return formulation;
- frequency or frequency grid;
- transposition/section assumptions;
- unit system.

Outputs include phase matrices, sequence or modal quantities where requested, characteristic values, and reports. Geometry must be physically valid: duplicate conductors, nonpositive heights/radii, invalid bundles, or inconsistent units must be rejected.

# Cable models

## Cable geometry

Cable geometry supports nested conductive and dielectric layers, screens/sheaths, armor, concentric arrangements, offsets, and multiphase placement. Each radial layer requires inner/outer radius, material properties, and electrical role. Off-center or multi-layer configurations require explicit geometric consistency checks.

## Cable impedance and admittance

Cable-constant calculations account for conductor internal impedance, sheath/armor paths, dielectric capacitance, and mutual coupling according to the implemented formulation. Document:

- conductor and screen bonding assumptions;
- material resistivity and permeability;
- dielectric permittivity and loss where supported;
- ground/installation geometry;
- frequency grid;
- matrix ordering and reduction policy.

Outputs should retain full phase/conductor matrices before any sequence or reduced equivalent. A cable-frequency scan is not the same as a thermal ampacity, sheath-loss, or installation-derating calculation unless those studies are separately implemented.

## Nested cable matrices

Nested cable assembly builds system matrices from layer-level contributions. Numerical checks should include symmetry/reciprocity expectations, positive-real behavior, conditioning, matrix dimension, and continuity over frequency.

# Coupled-line fitting and passivity

The coupled-line fitting layer handles matrix-valued frequency responses, pole/residue identification, state-space realization, passivity analysis, and correction.

Required evidence includes:

- original sampled matrices and units;
- weighting and scaling;
- selected order;
- fit error versus frequency;
- stable pole set;
- reciprocity/symmetry handling;
- minimum passivity margin before and after correction;
- state-space realization used at runtime;
- deterministic serialization and restoration.

Passivity correction must be reported as a transformation, not hidden. The corrected model should be compared with the uncorrected data so users can see the accuracy/passivity tradeoff.

# Transformer models

Transformer fidelity should follow the phenomenon and available test/design data. AIMORA exposes a hierarchy rather than one universal transformer.

## Parameter conversion and branch generation

The transformer-parameter study converts ratings, winding data, short-circuit tests, no-load tests, vector groups, and bases into electrical branch parameters. Inputs require explicit test basis, temperature, tap position, winding order, and unit convention.

Outputs may include per-winding resistance/leakage, magnetizing branch values, turns ratios, matrices, assumptions, and a generated branch representation. Conversion does not create missing test information; ambiguous allocation rules must be stated.

## Low-frequency terminal-matrix model

This model represents coupled terminal behavior through low-frequency resistance/inductance or admittance matrices. It is suitable when winding coupling matters but fast internal resonances do not.

Document terminal order, reference directions, matrix construction, grounding, initial flux/current, and frequency basis. It does not resolve detailed winding geometry or wideband internal nodes.

## BCTRAN-style model

A BCTRAN-style representation uses test-derived multiwinding terminal matrices. Required data include complete test set or a documented reconstruction, winding/terminal order, vector group, grounding, and base conversion.

Acceptance should check matrix symmetry/physical consistency, open/short-circuit reproduction, energy behavior, and terminal KCL. The name indicates modeling style, not certification against a specific commercial implementation.

## Hybrid transformer

A hybrid model combines leakage/capacitance networks with a nonlinear magnetic core. It can represent energization and selected higher-frequency terminal effects while retaining a physically meaningful core state.

Required data include winding leakage/capacitance, core topology, magnetization/saturation data, losses, initial/remanent flux, connection, and event schedule. Results should include terminal quantities, core flux, magnetizing current, energy, and flux/KCL residuals.

## Magnetic-equivalent-circuit model

The magnetic-equivalent model resolves reluctance branches, windings, leakage paths, and nonlinear magnetic state. Use it when core-leg/yoke flux distribution or multi-limb behavior is material and corresponding geometry/material data exist.

Limitations must identify omitted eddy-current, hysteresis, thermal, mechanical, and stray-capacitance effects.

## Wideband black-box transformer

A wideband terminal model uses passive rational multiport data derived from measurement, electromagnetic calculation, or synthetic reference data. Document port order, reference impedance, frequency range, fit order, passivity enforcement, and any delay treatment.

It reproduces terminal behavior within the fit domain but does not expose internal physical stresses unless those outputs are part of the identified model.

## Grey-box transformer

A grey-box model combines physically interpretable internal nodes/elements with identified parameters. It is useful when terminal measurements and partial design knowledge are available. Every identified parameter should be distinguished from directly known geometry or material data.

## White-box transformer

A white-box model derives winding sections, capacitances, inductive coupling, and internal nodes from geometry/material information. It can expose internal voltage distribution but requires substantially more data and validation. Mesh/section resolution, frequency dependence, loss model, and boundary conditions must be reported.

# Reactor models

Reactor families include shunt, series, neutral, and smoothing reactors. Depending on fidelity, they may use a linear branch, saturation/hysteresis, coupled phases, core/air-core geometry, or wideband representation.

Required data include rating, connection, inductance/reactance basis, resistance/losses, saturation data where used, grounding, initial flux/current, and frequency domain. Outputs include terminal voltage/current, reactive power, flux/current state, losses, and energy.

A reactor model does not automatically include thermal capability, acoustic behavior, mechanical force, protection, or insulation coordination.

# Rotating machines

A machine model couples terminal electromagnetic equations with rotor electrical state, shaft dynamics, controls, events, and energy accounting. Positive current/power/torque conventions must be explicit.

## Wound-field synchronous machine

Represents stator electrical behavior, field and damper circuits, rotor angle/speed, electromagnetic torque, saturation, and optional excitation/governor/stabilizer tasks.

Required data may include stator resistance, d/q inductances or reactances, field/damper parameters, inertia, damping, pole pairs, base values, saturation data, mechanical torque/power, initial operating point, and controls.

Outputs should include phase/dq quantities, field/damper state, rotor angle/speed, torque, electrical/mechanical power, stored/dissipated energy, unbalance metrics, and residuals.

## Cage induction machine

Represents stator and cage rotor state, slip, electromagnetic torque, and shaft dynamics. Required inputs include stator/rotor resistances and inductances, magnetizing branch, inertia, load torque, pole pairs, and initial speed/slip.

A single-cage model may be inadequate for deep-bar or double-cage starting behavior.

## Deep-bar or multi-branch induction machine

Uses multiple passive rotor branches to reproduce frequency-dependent rotor behavior. Parameter identification and passivity are central. Report branch values, fitting source, slip/frequency domain, and comparison with torque/current evidence.

## Wound-rotor induction and doubly fed induction machine

These models expose a rotor electrical port rather than a shorted cage. Document stator and rotor reference frames, turns/base conversion, rotor supply/converter boundary, power signs, shaft state, and control assumptions.

## Permanent-magnet synchronous machine

Includes permanent flux and saliency with rotor/shaft dynamics. Required data include d/q inductances, stator resistance, permanent flux linkage, pole pairs, inertia, damping, initial angle/speed, and mechanical input/load.

It does not automatically include demagnetization, temperature dependence, iron loss, spatial harmonics, or inverter control unless explicitly coupled.

## Synchronous condenser

A synchronous condenser is a synchronous-machine application with reactive-support operating conditions and no sustained prime-mover output. Field control, losses, inertia, and event behavior should be represented according to the study objective.

## Multi-mass shaft and controls

A multi-mass shaft represents inertias, shaft stiffness/damping, relative angles, and torsional torque. Exciters, governors, stabilizers, limiters, and sampled tasks add scheduler/discrete state.

Required reporting includes:

- mass ordering and mechanical base;
- inertia, stiffness, damping, and natural-frequency checks;
- electrical–mechanical sign convention;
- control sample/delay/hold policy;
- limiter and anti-windup behavior;
- event sequence;
- restart equivalence of all mechanical and control states.

# Power-electronic converters

## Average-value inverter

An average-value model replaces switching devices with averaged terminal behavior. It is appropriate for slower control/system studies when switching ripple, dead time, semiconductor commutation, and carrier harmonics are not required.

Document modulation/control equations, DC and AC ports, filters, limits, sample rate, initialization, and power balance. Do not use average-value results to claim semiconductor stress or switching-frequency harmonic performance.

## Switch-detailed two-level VSC

A switching-detailed VSC resolves gate states, pole voltages, antiparallel conduction, DC-link dynamics, filter current, events, and sampled control calendars.

Typical required data include:

- AC system and filter/leakage values;
- DC source, source resistance, and DC-link capacitance;
- semiconductor on/off representation;
- carrier frequency and modulation method;
- controller sample period, computational delay, and hold;
- dead time and gate interlock;
- current/voltage limits and protection logic;
- initial DC-link and controller state;
- electrical timestep small enough for the declared validity domain.

Outputs may include pole/line voltages, phase/filter currents, DC voltage/current, P/Q, gates, device conduction states, losses, stored energy, external power, KCL/energy residuals, protection state, exact event/commutation occurrences, and harmonic metadata.

A released switching slice must not be interpreted as support for every topology, PLL, grid-forming method, four-wire zero sequence, LCL resonance, reverse recovery, nonlinear capacitance, electrothermal behavior, or manufacturer-specific device.

## Semiconductor models

Semiconductor fidelity may range from ideal controlled switches to devices with finite conduction behavior, antiparallel paths, switching transition approximations, charge/recovery, capacitance, or loss maps.

For each device, document:

- supported conduction directions;
- gate/state logic;
- on/off constitutive law;
- switching transition/recovery model;
- parasitic capacitance/charge model;
- temperature assumption;
- timestep and event requirements;
- loss/energy interpretation;
- unsupported avalanche, thermal, aging, or failure phenomena.

## Bridge topologies

Generic bridge composition supports combinations such as two-level bridges, diode/thyristor bridges, choppers, neutral-point-clamped, T-type, flying-capacitor, and cascaded H-bridge structures where the corresponding public declarations and execution routes are present.

Topology documentation must identify nodes, device orientation, allowed switching states, capacitor balancing assumptions, neutral-point state, arm/phase ordering, and invalid gate combinations. A topology declaration without an executable qualified case is not a production claim.

## Converter controls and filters

Control families may include known-angle synchronous-reference-frame control, PLL-based dq control, stationary-frame PR control, droop, virtual-synchronous behavior, limiters, protection, and exact sampled tasks where implemented.

Filters may include L, leakage-equivalent, or declared extended filter structures. For every control/filter combination record:

- measured quantities and frames;
- transformations and angle source;
- gains, limits, anti-windup, and initialization;
- sample, delay, hold, carrier, and gate calendars;
- filter topology, damping, and resonance;
- fault/block/restart sequence;
- operating and validity domain.

# Control expressions and native components

## Control expressions and TACS-style logic

Control expressions combine signals, algebraic operations, dynamic blocks, comparisons, logic, and sampled state. Evaluation order, direct feedthrough, algebraic loops, initialization, saturation, and delay must be explicit.

A control output should be typed and unit-aware. Mixing physical quantities without documented scaling is an error even when dimensions happen to be numerically compatible.

## General multirate task platform

Multirate tasks execute on exact rational schedules with dependency order, delayed holds, event/release collision rules, rollback, and checkpoint state. Task families can include sensing, estimation, control, modulation, protection, reporting, and other declared functions.

Acceptance requires exact release calendars, deterministic ordering, no hidden resampling, atomic rollback, and restart equivalence across every task state.

## User-defined native components

Native components can extend composition through explicit registration and a defined interface. A user-defined component must provide:

- stable type/registration identity;
- terminal/port contract;
- parameter and unit validation;
- state inventory;
- residual/Jacobian or companion contribution;
- event and rollback behavior;
- serialization/checkpoint behavior;
- result quantities and diagnostics;
- tests and at least one case.

Registration must be explicit. Loading a package should not silently alter existing model semantics.

# Model-selection matrix

| Engineering need | Preferred starting family | Escalate when |
|---|---|---|
| Low-frequency feeder/network transient | Lumped R/L/C or cascaded π | Propagation delay or frequency dependence changes results |
| Travelling-wave switching surge | Bergeron/modal line | Loss/dispersion varies materially with frequency |
| Fast-front line/cable study | Sampled/rational/wideband model | Geometry or measured data require a different representation |
| Cable parameter calculation | Cable geometry and constants | Thermal/sheath studies are separately required |
| Basic transformer system transient | Low-frequency/BCTRAN-style | Core nonlinearity or internal resonance is material |
| Transformer inrush/core behavior | Hybrid or magnetic-equivalent | Internal winding voltage distribution is required |
| Transformer terminal wideband behavior | Wideband black-box | Internal physical stress is required |
| Internal transformer winding stress | Grey-/white-box | Data quality cannot support the detail |
| Machine electromechanical transient | Appropriate electromagnetic machine plus shaft | Control/torsional detail is material |
| Converter control/system behavior | Average-value inverter | Ripple, dead time, commutation, or device stress matters |
| Converter switching transient | Switch-detailed VSC/bridge | Device charge/thermal physics matters |
| Nonlinear protection device | Arrester/nonlinear branch | Thermal/failure or spatial effects matter |

# Evidence and completeness

A model is professionally documented only when all of the following exist:

- engineering purpose and selection guidance;
- complete parameter table with units and signs;
- state and initialization definition;
- validity domain and unsupported phenomena;
- deterministic event/update order;
- result and diagnostic contract;
- analytical/manufactured/reference evidence;
- at least one runnable case;
- conservation/passivity/convergence checks as applicable;
- checkpoint/restart evidence for stateful models.

The generated model index exposes every declaration so undocumented additions cannot remain invisible. It does not turn an internal helper declaration into a supported user-facing model; maturity and evidence still control the claim.
