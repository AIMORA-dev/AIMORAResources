# Deck-Card Reference

AIMORA decks are electrical-model data. They are parsed into typed Julia models and are not executable source code. The parser supports readable and fixed-field records, continuation cards, named sections, case sequences, and explicit request markers. Unknown or malformed records are rejected with line/column context.

## General rules

- Preserve the declared field widths for fixed-field records.
- State units and bases explicitly when the card family permits multiple conventions.
- Use unique node, component, signal, output, and case identifiers.
- Define terminal orientation and grounding explicitly.
- Continuations belong only to the immediately preceding compatible card.
- A request marker never creates missing physics; it selects output from an admitted model.
- Unsupported fields are errors or retained inert extension data according to the documented schema; they are never guessed.

## Simulation-control cards

These records define timestep, end time, integration method, output sampling, initialization, case boundaries, restart/checkpoint behavior, tolerances, and execution options.

Required checks include:

- positive timestep and duration;
- event times inside the simulation horizon;
- output schedule compatible with the numerical timestep;
- declared fixed-step method supported by all active models;
- restart file/schema/revision compatibility;
- no contradictory case or initialization directives.

## Node and topology records

Topology cards establish node names, reference/ground nodes, phase/conductor identity, terminal aliases, and network sections. Node identity is case-sensitive according to the active syntax profile. A terminal cannot silently change phase or reference across continuations.

## Branch cards

| Family | Typical fields | Resulting model |
| --- | --- | --- |
| R | from node, to node, resistance/conductance | resistor |
| L | terminals, inductance, initial current | inductor companion |
| C | terminals, capacitance, initial voltage | capacitor companion |
| R–L | terminals, R, L, initial current | series R–L companion |
| R–L–C | terminals, R, L, C, initial conditions | series R–L–C branch |
| coupled branch | terminal sets, matrix or sequence data | coupled multiport branch |

Negative passive parameters, invalid unit conversions, zero/duplicate terminal definitions, and incompatible initial states are rejected.

## Source cards

Source records define voltage/current type, waveform, amplitude, phase, frequency, timing, orientation, and optional control reference. Impulse sources additionally declare front/tail definitions. Thevenin/Norton behavior requires explicit impedance/admittance records; it is not inferred from a source card alone.

## Switch and breaker cards

Switch cards declare terminal nodes, initial state, open/closed conductance, operation times or control signal, zero-current or restrike behavior, event priority, and chatter/debounce policy. Multi-pole sequences declare pole identity and timing separately.

A switch event must be reachable within the case horizon. Contradictory open/close operations at the same priority are rejected.

## Output and measurement cards

Output cards request node voltage, branch current, power, energy, internal admitted state, control signal, machine quantity, instrument channel, or derived typed quantity. They declare:

- target identity;
- quantity and orientation;
- units or per-unit base;
- sample schedule;
- optional aggregation such as RMS/phasor only when the corresponding measurement contract is admitted.

A request for a nonexistent or private-only variable is rejected.

## TACS and control cards

Control records include source, gain, sum, product, limiter, deadband, filter, transfer function, delay, comparator, logic, sampled task, pulse, and controlled electrical interface. Continuations may carry coefficients, schedules, or signal lists.

Every control graph must pass signal existence, unit compatibility, causality, algebraic-loop, schedule, initial-state, and limit checks.

## Overhead-line cards

Line-geometry records describe conductor coordinates, radius/GMR, resistance/material, bundles, circuits, earth wires, transposition, earth return, frequency, and reduction/sequence requests. Runtime-line records may reference generated line constants, propagation delays, modes, or fitted frequency-dependent products.

Conductor ordering and phase mapping are part of the result contract. Geometry is rejected when conductors overlap, dimensions are nonphysical, or requested transformations are undefined.

## Cable cards

Cable cards describe conductor, insulation, sheath/screen, armour, semiconductive layers, material properties, burial/spacing geometry, bonding/grounding, earth, and frequency grid. Layer radii must be strictly ordered. Bonding and terminal conditions are explicit.

## Transformer and reactor cards

Transformer records cover winding terminals, ratings, bases, connection, phase shift, winding order, leakage, magnetizing branch, losses, tap state, saturation/residual flux, capacitance, and fidelity tier. Parameter-conversion cards reference nameplate and test data.

Multi-winding cards must identify every winding consistently. A test value cannot be applied on an unstated base.

## Nonlinear-device cards

Nonlinear records define piecewise, polynomial, exponential, arrester, saturable, hysteretic, or ideal-constraint behavior. Curve points must be ordered and units compatible. Extrapolation and limiting rules are explicit. Unsupported discontinuities are rejected rather than smoothed invisibly.

## Machine cards

Machine records cover family, phase terminals, electrical parameters, rotor/field circuits, saturation, mechanical base, inertia, shaft/load, initial speed/angle/slip, controls, and output requests. Deep-bar and multi-mass continuations define passive rotor branches or shaft sections.

A machine card does not infer a feasible operating point. Initialization must prove consistency or report the residual and admitted startup transient.

## Converter and semiconductor cards

Converter cards define topology, AC/DC terminals, valve family, modulation or firing signals, switching schedule, deadtime, filters, DC-link state, limits, and fidelity. A declared average-value model cannot accept switching-detail requests.

## Case-sequence and include cards

Case sequences permit versioned parameter/event variations while retaining common source data. Includes are resolved only inside admitted roots, with cycle detection and portable paths. Absolute workstation paths, credentials, and network fetches are prohibited in public cases.

## Fixed-field parsing diagnostics

A parse diagnostic reports:

- file and line;
- section/card family;
- field or column range;
- received text;
- expected type/unit/domain;
- continuation context;
- whether execution is blocked.

The parser preserves original source locations so project and report diagnostics can trace back to the exact input record.

## Validation checklist

Before execution, confirm:

1. all cards are recognized;
2. identifiers and terminal references resolve;
3. units, bases, signs, and phases are consistent;
4. parameter domains are physical;
5. continuations match their owner card;
6. requested model fidelity is available;
7. events and schedules are reachable;
8. outputs reference public typed quantities;
9. no include/path/licence boundary is violated;
10. the selected solver advertises every required capability.
