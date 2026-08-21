# Deck and Card Reference

AIMORA supports typed deck parsing for reusable engineering input and classic fixed-field compatibility. The generated [Deck and Card Declaration Index](generated/deck-card-index.md) scans every public parser owner and lists all detected card/parser declarations and fields. This chapter explains how those declarations are used safely.

## Design principles

1. **Deterministic interpretation** — identical text and revisions produce identical typed input.
2. **Typed conversion** — numbers, booleans, identifiers, matrices, and enums are validated before execution.
3. **No silent omission** — unknown or malformed cards are rejected or reported explicitly.
4. **Explicit units and bases** — a value is not accepted as an engineering quantity when its unit/base is ambiguous.
5. **Traceable continuations** — continuation records belong to a specific parent card and preserve order.
6. **Study separation** — cards are interpreted in the context of a declared study; unrelated fields are not guessed.
7. **Source location in diagnostics** — errors identify file, section/card family, row, and field where possible.
8. **Round-trip awareness** — normalized output may differ in formatting but should preserve the typed meaning.

# Deck lifecycle

```text
text file
  ↓ lexical rows and comments
section/request markers
  ↓
fixed-field or tokenized field extraction
  ↓
continuation attachment and dispatch
  ↓
typed card records
  ↓
semantic validation and cross-reference resolution
  ↓
study/model request
  ↓
solver assembly and execution
  ↓
typed results, reports, and queries
```

Parsing success does not prove that a study or model is implemented. After parsing, the study catalog and capability checks still apply.

# General file rules

## Encoding and line endings

Use UTF-8 text. Normalize CRLF/LF differences before review. Avoid invisible control characters and tabs in strict fixed-field sections unless the grammar explicitly allows them.

## Comments and blank lines

Comments should describe engineering intent, source, units, and assumptions. Do not encode required data only in comments. Blank lines may delimit logical groups but must not be relied on when a section marker is required.

## Identifiers

Use stable, unique identifiers for buses/nodes, branches, devices, controls, windings, conductors, cases, and outputs. Avoid identifiers that differ only by whitespace or case where the parser normalizes them.

## Numbers

Use explicit decimal/scientific notation supported by the parser. Reject nonfinite values. A parser may accept a syntactically valid number that is physically invalid; semantic validation must still enforce positivity, bounds, matrix dimensions, and validity domains.

## Units

When a card family has fixed historical units, document them beside the case and do not mix them with SI fields. For modern typed inputs, prefer explicit units or a declared unit system. Every per-unit value requires its base.

# Section and request markers

Deck-level markers establish the active study, request type, case boundary, or input section. They control which row grammar follows and how results are requested.

Professional use requires:

- one unambiguous active section at a time;
- deterministic termination of sections;
- rejection of unsupported nesting;
- clear behavior for repeated sections;
- a typed request marker rather than inference from filename;
- explicit end-of-case handling.

The parser owners for deck files and request markers also handle query/result requests. Consult the generated declaration index for the complete current set.

# Fixed-field sections

Classic EMTP-style decks can use column-based records. In fixed-field mode:

- column positions are part of the grammar;
- tabs can corrupt interpretation;
- blank fields are distinct from zero;
- continuation and sign columns must be preserved;
- unit assumptions may be inherited from the historical card family;
- overflow or truncated values must be rejected.

When converting a fixed-field deck to a modern typed case, retain the original file as provenance and document every normalization or unit conversion.

# Continuations and dispatch

Complex cards may require continuation rows for matrices, frequency samples, control parameters, geometry, or device details.

A continuation record must:

- attach to a compatible parent type;
- occur in a permitted order;
- satisfy the expected field count/dimensions;
- not be reused by another parent;
- produce an error when orphaned;
- preserve all values required for reconstruction.

Dispatch selects the typed card family from markers, section state, and row content. Unknown dispatch must not fall through to a superficially similar card.

# Case sequences and multiple runs

Case-sequence cards define a controlled series of related executions, parameter changes, or continuation states.

Document:

- sequence identifier and ordering;
- inherited versus overridden data;
- initial-state and restart relationship;
- output-directory isolation;
- failure policy: stop, continue, or mark downstream cases blocked;
- comparison/aggregation method.

A sequence must not overwrite the evidence of an earlier case unless that behavior is explicitly requested and recorded.

# Network branch cards

Branch cards describe terminals and lumped electrical parameters such as resistance, inductance, capacitance, coupling, and initial conditions.

Typical required fields are:

- from/to node or terminal;
- device/circuit identifier;
- phase or conductor order;
- R, L, C, G, or matrix values;
- initial current/voltage where applicable;
- status and event association;
- output request flags.

Validation should reject self-connections where unsupported, duplicate identities, incompatible matrices, nonphysical values, and ambiguous units.

# Source and generator-equivalent cards

Source cards define prescribed voltage/current waveforms or equivalent sources. Generator-equivalent cards define a finite source behind impedance or an appropriate machine/equivalent boundary.

Document:

- waveform type;
- magnitude convention: RMS, peak, or instantaneous;
- frequency, phase, and sequence;
- source impedance and grounding;
- energization/ramp time;
- positive direction;
- whether the source is an imposed boundary or solved dynamic model.

An ideal voltage source and a finite Thevenin source are not interchangeable.

# Switch and event cards

Switch cards define initial state, open/close requests, current-zero policy, controlled operation, and finite on/off behavior where supported.

Required review items:

- topology and terminal identity;
- initial state;
- requested times or control signal;
- event-grid alignment/localization;
- simultaneous-event priority;
- on/off resistance or leakage;
- interruption/restrike/dead-time rules;
- output state and occurrence reporting.

A requested transition time should not be confused with a physically executed current-zero interruption time.

# Output, query, and result cards

Output cards select quantities, devices/nodes, sampling, analysis windows, and report forms. Query/result cards retrieve typed values or metadata after parsing/execution.

Every output request should state:

- quantity key;
- target identity;
- unit/base expectation;
- instantaneous, RMS, phasor, harmonic, or averaged form;
- sampling/decimation policy;
- start/stop analysis window;
- aggregation or statistic;
- destination format.

Unknown targets or quantities must be rejected. An empty output request must not silently become “export everything” when that can create excessive or ambiguous data.

# Control and TACS cards

Control/TACS cards describe signals, arithmetic, dynamic blocks, logical operations, limits, delays, sampling, and connections.

Required semantics include:

- input/output quantity and unit;
- direct feedthrough and algebraic-loop behavior;
- state and initialization;
- sample period, phase, computational delay, and zero-order hold;
- saturation, limiter, anti-windup, and reset;
- dependency order;
- event/rollback/checkpoint behavior.

The parser must not permit a control signal to reference an undefined or dimensionally incompatible quantity.

# Line cards

Line cards can represent lumped/cascaded-π, Bergeron, modal, phase-domain, sampled-frequency, Semlyen/rational, and wideband models according to the available declarations.

Common fields include:

- sending/receiving terminals;
- phase/conductor order;
- length and units;
- R/L/C/G or Z/Y matrices;
- propagation delay or velocity;
- characteristic values;
- modal transformation;
- frequency samples;
- rational poles/residues/state-space data;
- loss and ground-return policy;
- initial/history state.

The selected card must match the actual parameter representation. A constant-parameter line card must not be populated with frequency-dependent data that the runtime will ignore.

# Rational-frequency and Semlyen line cards

These cards define a fitted dynamic line representation. Required information can include frequency grid, weighting, pole/residue data, delays, transformations, and passivity/stability metadata.

Validation should check:

- finite, ordered frequencies;
- compatible matrix dimensions;
- stable poles;
- real-conjugate consistency;
- delay positivity;
- passivity/correction metadata;
- state-space realization dimensions;
- declared fit domain.

A rational model should carry a fit report or source identifier rather than anonymous coefficients.

# Overhead-line constants cards

Geometry cards specify conductors, bundles, phase identity, coordinates, material data, frequency, and earth model.

Required checks include:

- positive radius/GMR/resistance where required;
- physically valid conductor coordinates and heights;
- no duplicate conductor position;
- valid bundle count/spacing;
- explicit length/coordinate units;
- consistent phase and ground-wire classification;
- valid frequency/earth properties;
- requested matrix/sequence/modal outputs.

# Cable-constants cards

Cable cards describe conductor, insulation, sheath/screen, armor, dielectric layers, placement, bonding, material properties, and frequency scan.

Required checks include:

- strictly ordered inner/outer radii;
- valid material properties;
- complete layer ownership and conductor order;
- compatible centered/off-center geometry;
- valid phase placement and installation data;
- explicit bonding/reduction assumptions;
- matrix dimension and requested output consistency.

Do not use cable electrical-constant cards as thermal ampacity or pulling input without a separate implemented study.

# Transformer cards

Transformer cards can represent parameter conversion, low-frequency matrices, BCTRAN-style data, hybrid/magnetic-equivalent circuits, wideband multiports, and grey-/white-box internal networks.

Depending on fidelity, fields can include:

- winding/terminal identity and order;
- ratings, bases, turns ratios, vector group, and tap;
- resistance/leakage and coupling matrices;
- short-circuit/no-load test data;
- magnetization/saturation/hysteresis data;
- capacitance/internal-node data;
- geometry/material section data;
- frequency samples or rational realization;
- initial flux/state;
- grounding and connection.

The parser should reject incomplete matrix blocks, duplicate windings, inconsistent test bases, impossible connections, and unsupported fidelity combinations.

# Reactor cards

Reactor cards distinguish shunt, series, neutral, and smoothing applications and their linear/nonlinear/coupled forms.

Document rating, connection, impedance/inductance basis, resistance/loss, saturation data, grounding, initial state, and output requests. A generic inductor card may be sufficient for a simple case, but it should not be described as a qualified nonlinear reactor without the required model and evidence.

# Nonlinear-element cards

Nonlinear cards define constitutive curves/equations, coefficients, interpolation, initial branch/state, and solver policy.

Required checks include:

- monotonicity/passivity where expected;
- finite coefficients and breakpoints;
- ordered independent-variable points;
- explicit units and signs;
- derivative/Jacobian availability or numerical policy;
- extrapolation behavior;
- valid initial operating point;
- energy/thermal limits where represented.

# Machine cards

Machine cards can describe synchronous, cage/deep-bar/wound-rotor induction, permanent-magnet, doubly fed, synchronous-condenser, shaft, saturation, excitation, governor, stabilizer, and limiter data.

Common required fields include:

- terminal/phase order and grounding;
- electrical rating/base/frequency;
- resistance and inductance/reactance parameters;
- field/damper/rotor branch data;
- pole pairs and frame/sign convention;
- inertia, damping, shaft masses, stiffness, and torque;
- saturation/permanent flux;
- initial angle, speed, currents, fluxes, or operating point;
- control parameters and exact schedules;
- event and output requests.

Parser success is not enough: machine parameters must satisfy passivity, base, and validity checks, and controls must have deterministic state/update order.

# Converter and semiconductor cards

Converter cards describe DC/AC terminals, bridge topology, semiconductor positions, filter, modulation, controls, protection, and events.

Required fields can include:

- topology and device orientation;
- DC source/link parameters;
- AC source/grid and filter/leakage;
- carrier/modulation method;
- controller and frame/angle source;
- sample, delay, hold, dead time, and timestep;
- current/voltage/protection limits;
- semiconductor conduction/switching parameters;
- initial capacitor/control state;
- requested gate/device/electrical outputs.

Reject invalid gate combinations, incompatible phase counts, nonpositive energy-storage values, event times outside the calendar, and requests outside the declared timestep/voltage/frequency domain.

# Initialization cards

Initialization cards can request zero state, calculated steady state, explicit state values, imported state, or checkpoint restoration.

An initialization record must identify the model/state version and all required state families. Partial state restoration should fail unless the model explicitly defines a safe completion rule.

# Restart and checkpoint cards

Restart cards identify the checkpoint source, target continuation time, and compatibility policy.

Validation should compare:

- engine/model/solver schema version;
- topology and model identity;
- timestep/scheduler policy;
- state dimensions and ordering;
- delayed-history buffers;
- control/protection/event state;
- random state where present;
- checksum/integrity metadata.

A checkpoint from an incompatible revision should be rejected rather than approximately interpreted.

# Parser diagnostics

A professional parser error should provide:

```text
file:line
section/card family
field or column range
received token/value
expected type/unit/domain
corrective guidance
```

Diagnostic categories should distinguish syntax, conversion, missing field, duplicate identity, unresolved reference, dimensional mismatch, invalid physical domain, unsupported capability, and not-implemented study.

# Minimal modern deck example

The exact syntax depends on the selected typed card family, but a complete deck should make the following intent explicit:

```text
study / request
simulation timestep and horizon
nodes and topology
sources and branches
model-specific continuation data
initial conditions
switch/control events
outputs and analysis windows
end of case
```

Start from a registered case instead of creating an undocumented format from scratch. The generated [Complete Runnable Case Catalog](generated/case-catalog.md) gives the input and entrypoint for every public example.

# Adding or changing a card family

A parser contribution is incomplete until it has:

1. typed representation or documented dispatch owner;
2. syntax and field/column specification;
3. units, bases, defaults, and required/optional fields;
4. continuation and ordering rules;
5. semantic validation and cross-reference resolution;
6. precise errors for malformed and unsupported input;
7. round-trip or normalization tests where applicable;
8. at least one valid example deck;
9. invalid-input tests;
10. model/study/result documentation and release note.

The generated declaration index makes all parser owners visible. It should be reviewed whenever the parser changes so no new accepted card remains undocumented.
