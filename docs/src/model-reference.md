# Model Reference

This reference describes accepted public model families and explicitly bounded planned families, their engineering meaning, principal inputs, generated state, study use, outputs, and important limitations. A named planned or case-specific family is not an executable availability claim. Exact constructors and deck syntax remain versioned API contracts; this page explains when and why each accepted family is used.

## Passive lumped branches

| Model | Principal data | Numerical/state meaning | Typical use | Key limitations |
| --- | --- | --- | --- | --- |
| Resistor | terminal nodes, resistance or conductance | static admittance | damping, burdens, losses, network equivalents | no frequency or thermal dependence unless explicitly modeled |
| Inductor | terminal nodes, inductance, initial current | companion conductance plus history current | reactors, source impedance, filters | ideal linear flux-current relation |
| Capacitor | terminal nodes, capacitance, initial voltage | companion conductance plus history source | shunts, filters, switching studies | ideal linear charge-voltage relation |
| Series R–L | terminals, R, L, initial current | combined trapezoidal companion | feeder/source equivalents, damping reactors | parameters are constant over the declared validity range |
| Series R–L–C | terminals, R, L, C, initial state | coupled energy-storage companion | resonance and energization studies | lumped representation is unsuitable when propagation matters |

All dynamic passive branches declare units, terminal orientation, initial state, integration method, accepted timestep domain, and stored-energy accounting.

## Sources and equivalents

- **Independent voltage source:** prescribed waveform, phase, frequency, timing, terminal orientation, and optional source impedance through an explicit branch.
- **Independent current source:** prescribed injected current and orientation.
- **Thevenin equivalent:** voltage source plus explicit equivalent impedance; appropriate only within its stated frequency and operating domain.
- **Controlled source:** signal-driven source with declared control sampling, delay, saturation, and causality.
- **Lightning/impulse source (planned general family):** surge packets may use case-specific prescribed waveforms, but AIMORA does not yet claim a general accepted lightning-source study family.

Sources do not infer a hidden grounding convention. Reference nodes and polarity remain explicit.

## Switches, breakers, and discontinuities

| Family | Status | Behavior |
| --- | --- | --- |
| Timed ideal switch | implemented | changes topology at declared times |
| Controlled switch | implemented | follows a typed control or TACS signal |
| Current-zero switch | case-specific/retained compatibility only | opens only after an explicitly admitted current-zero condition; no general protection-family claim |
| Restrike/reignition switch | planned | requires a separately accepted voltage/current/event and arc-domain model |
| Breaker sequence | planned | requires the future protection packet for coordinated pole operations, reclosing, lockout, and qualified restart state |

Switching models declare closed/open conductance, event priority, chatter protection, interpolation/localization rules, and state included in checkpoints. An ideal switch is a numerical constraint, not a physical arc model.

## TACS and control blocks

The control platform includes signal sources, gains, sums, products, limiters, deadbands, filters, delays, transfer functions, sampled tasks, logic, comparators, pulse generation, and controlled electrical interfaces. Every control block declares:

- input and output units;
- continuous or sampled execution;
- exact rational schedule where sampled;
- direct-feedthrough and algebraic-loop behavior;
- limits, anti-windup, and reset rules;
- event interaction and checkpoint state.

Controls do not bypass the physical network solver. Electrical effects enter through registered typed components.

## Overhead-line and cable models

### Geometry and constants

Line- and cable-constants calculations derive frequency-dependent series impedance and shunt admittance from explicit geometry, conductor/material data, earth return, sheath/screen construction, bonding, and frequency settings.

### Runtime representations

| Representation | Use | Required caution |
| --- | --- | --- |
| Lumped π or multi-section | electrically short lines and low-frequency studies | section count and frequency validity must be justified |
| Bergeron/travelling-wave | propagation with fixed delay and characteristic impedance | frequency dependence is approximated |
| Modal line | decoupled or weakly coupled modal propagation | modal transformation validity must be checked |
| Frequency-dependent fitted line | wide-frequency transient studies | fit error, passivity, delays, poles, and extrapolation limits must be reported |
| Wideband cable | cable/sheath coupling over a declared band | construction, bonding, earth, and terminal treatment are essential |

Coupled-line fitting records frequency samples, weighting, candidate poles, relocation, residues, delay extraction, continuous passivity certificate, enforcement changes, uncertainty, and runtime realization. A fitted model must be rejected outside its admitted domain rather than extrapolated silently.

## Nonlinear branches

- exponential and polynomial static characteristics;
- ZnO/surge-arrester characteristics (planned general surge-family qualification);
- saturable and hysteretic magnetic branches;
- piecewise characteristics with explicit interpolation;
- ideal algebraic constraints;
- user-registered nonlinear devices through the public extension contract.

Nonlinear models declare scaling, residual/Jacobian behavior, limits, branch orientation, event surfaces, state acceptance, rollback, and convergence diagnostics. Discontinuities are localized and chatter-protected.

## Transformers and reactors

AIMORA exposes multiple fidelity tiers. They represent different engineering questions and must not be substituted silently.

| Tier | Purpose |
| --- | --- |
| Low-frequency terminal matrix | coupled terminal behavior in the power-frequency and nearby range |
| BCTRAN-style model | multi-winding coupled leakage/magnetizing representation generated from test or design data |
| Hybrid model | leakage, capacitance, and nonlinear-core effects |
| Magnetic-equivalent-circuit model | explicit nonlinear core limbs/yokes and winding coupling |
| Wideband black-box model | passive rational multiport fitted to terminal response |
| Grey-box model | physical internal-node ladder with identified parameters |
| White-box model | geometry-owned winding sections and detailed internal coupling |

Transformer connection, phase shift, grounding, winding orientation, tap state, saturation, residual flux, capacitance, losses, and test-data provenance remain explicit. Reactor families include shunt, series, neutral, and smoothing reactors with linear or admitted nonlinear magnetic behavior.

## Rotating machines

### Wound-field synchronous machine

Owns stator/rotor electrical state, field and damper circuits, saliency, saturation, shaft mechanics, initial operating point, torque/electrical power, and terminal phase-domain interaction. Optional excitation, governor, stabilizer, and limiter tasks declare schedules and limits.

### Cage induction machine

Represents stator and cage-rotor state, slip, electromagnetic torque, mechanical load, inertia, and unbalance. Deep-bar variants use multiple passive rotor branches and must report the admitted frequency/slip domain.

### Wound-rotor and doubly fed induction machines

Expose an explicit rotor port, rotor electrical power, converter or external connection, shaft state, and operating-mode assumptions.

### Permanent-magnet synchronous machine

Owns permanent flux, saliency, stator state, torque, shaft dynamics, and declared demagnetization/thermal limitations.

### Synchronous condenser

Uses synchronous-machine electrical and mechanical state with reactive-power/excitation objectives and no hidden prime-mover assumption.

### Shaft systems

Single-mass and multi-mass shafts declare inertia, stiffness, damping, mechanical torque, speed/base conventions, torsional modes, initialization, and energy accounting.

## Power-electronic models

| Family | Status | Representation |
| --- | --- | --- |
| Average-value inverter | implemented bounded owner | averaged converter dynamics without individual switching ripple |
| Two-level switching VSC | implemented bounded owner | explicit valve states and switching events |
| Generic diode/controlled-valve bridge | implemented bounded owner | declared topology and nonlinear valve conduction within its accepted bridge cases |
| Semiconductor-fidelity extensions | implemented bounded owner | declared conduction, reverse recovery, charge, or switching-loss behavior where qualified |
| Buck, boost, inverting, four-quadrant and interleaved choppers | implemented bounded owners | average where released plus explicit switching state, physical passive state and detailed-device behavior |
| Dual-active bridge | implemented bounded owner | isolated average or switching bridge pair with transformer leakage, phase-shift modulation and DC energy state |
| NPC and T-type converters | implemented bounded owners | explicit multilevel switching states and neutral-point behavior |
| Flying-capacitor converter | implemented bounded owner | capacitor-state and switching-sequence behavior |
| Cascaded H-bridge | implemented bounded owner | two-through-eight cell state, capacitor balance and admitted modulation |
| Matrix converter and cycloconverter | implemented bounded owners | safe direct-conversion incidence/commutation or line-commutated bridge-group firing |

A converter model declares DC/AC terminals, modulation, switching schedule, deadtime, controls, filters, limits, initialization, losses, and fidelity. Average, switching-state and switching-detailed models answer different questions, and only the exact combinations in the public executable-fidelity matrix are admitted.

## Measurements and instrument chains

Public contracts cover CT, VT, CVT, sensors, burdens, analog filtering, sampling, digital filtering, instantaneous/RMS/phasor channels, uncertainty, event records, and checkpoint state. Instrument saturation, frequency response, calibration, timing, channel identity, and validity limits must remain visible in results.

## Native user-defined components

External Julia packages may register components through explicit extension contracts. A component must provide terminal identity, companion/residual behavior, state acceptance/rollback, snapshot support, units, readiness, and limitations. Project declarations are inert data; loading a project never executes arbitrary source code.

## Model selection checklist

Before selecting a model, document:

1. physical phenomenon of interest;
2. representation and fidelity;
3. frequency/time domain;
4. required parameters and their provenance;
5. initialization and events;
6. expected outputs and quality checks;
7. domain outside which the model must be refused.
