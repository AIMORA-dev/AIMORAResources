# Study Reference and Capability Maturity

AIMORA uses typed study descriptors so roadmap breadth is visible without confusing a declared interface with an implemented calculation. The generated [Complete Study Catalog](generated/study-catalog.md) lists every descriptor directly from the engine and is the authoritative inventory for identifiers, domains, and maturity.

## Maturity is part of the numerical contract

| Status | User meaning | Required behavior |
|---|---|---|
| `implemented` | A supported execution path exists for a declared validity domain | Validate input, execute, return a typed result and diagnostics |
| `prototype` | Experimental numerical path or interface | Mark experimental behavior and qualification gaps explicitly |
| `planned` | Roadmap/API descriptor only | Return a typed `not_implemented` result; never fabricate values |
| `legacy_reference` | Historical/reference capability | Use only for declared comparison or qualification, not production execution |

A filename, function stub, menu entry, or catalog row does not prove implementation. The descriptor status and returned result status control the claim.

# Implemented studies

At the current public-engine revision, the typed catalog marks four study families as implemented.

## Electromagnetic transient (`emt`)

### Purpose

Time-domain simulation of fast electrical and electromechanical phenomena with explicit events, dynamic state, delayed histories, nonlinear devices, sampled controls, and checkpoint/restart behavior.

### Typical applications

- RLC energization and discharge;
- capacitor-bank switching, interruption, restrike, and recovery voltage;
- travelling-wave line and cable transients;
- lightning and surge cases;
- transformer energization and nonlinear magnetic behavior;
- machine events, unbalance, torque changes, and control response;
- switching-detailed converters, bridge topologies, faults, block, clearance, and restart;
- nonlinear-network discontinuities;
- multirate control/protection tasks;
- deterministic restart and qualification cases.

### Required input classes

- topology and terminal identities;
- model parameters with units, bases, signs, and provenance;
- initial-state policy;
- timestep and horizon;
- event calendar and collision priority;
- control sample/delay/hold calendars where present;
- requested outputs and analysis windows;
- solver and convergence policy.

### Numerical state

An EMT case may contain differential, algebraic, discrete, delayed-history, scheduler, and random state. A checkpoint must preserve every state family necessary to reproduce uninterrupted execution.

### Result contract

Depending on the model and case, results can include:

- instantaneous terminal voltages and currents;
- powers and integrated energies;
- switching/gate/conduction states;
- line/cable histories and travelling-wave quantities;
- transformer flux and internal-node quantities;
- machine electrical, mechanical, and control state;
- converter DC/AC quantities and harmonic metadata;
- event occurrence and ordering;
- nonlinear iteration/convergence diagnostics;
- KCL, energy, passivity, and restart residuals;
- warnings, assumptions, and metadata.

### Acceptance

A successful process exit is not sufficient. Review model validity, event occurrence, convergence, conservation/passivity diagnostics, expected outputs, and comparison evidence. Where exact replay is claimed, the restarted trajectory must match the uninterrupted trajectory according to the case contract.

### Limitations

EMT support is model- and case-specific. It does not imply that every declared machine, converter, control, protection, thermal, electromagnetic-field, manufacturer, or standards workflow is qualified.

## Overhead-line constants (`line_constants`)

### Purpose

Calculate phase-domain impedance and capacitance/admittance quantities from overhead-conductor geometry, material data, bundle arrangement, earth model, and frequency.

### Required inputs

- conductor identity and phase order;
- x/y coordinates and units;
- radius/GMR and resistance;
- bundle count and spacing;
- frequency or frequency grid;
- earth resistivity and ground-return assumptions;
- transposition/section policy;
- requested phase, sequence, modal, or report outputs.

### Outputs

- phase impedance matrices;
- phase capacitance/admittance matrices;
- sequence/modal quantities where requested;
- characteristic quantities and propagation information where supported;
- frequency scans, text reports, CSV data, and plots in registered cases;
- assumptions and geometry validation diagnostics.

### Acceptance

Check physical geometry, units, matrix dimensions, symmetry/reciprocity expectations, continuity over frequency, positive-real behavior where applicable, and reproduction of reference/benchmark cases.

### Limitations

This study is not an ampacity, sag-tension, lightning-risk, insulation-coordination, or thermal-rating calculation. Those require separate implemented studies.

## Cable constants (`cable_constants`)

### Purpose

Calculate cable impedance/admittance and frequency-scan quantities from conductor, insulation, sheath/screen, armor, layer, placement, material, bonding, and installation data supported by the model.

### Required inputs

- radial layer geometry and conductor order;
- material resistivity/permeability;
- dielectric permittivity and losses where represented;
- sheath/screen/armor properties;
- phase placement, burial/ground assumptions, and earth properties;
- bonding/reduction assumptions represented by the selected case;
- frequency grid and output request.

### Outputs

- complete conductor/phase impedance matrices;
- capacitance/admittance matrices;
- reduced, sequence, modal, or characteristic quantities where requested;
- frequency scans and case reports;
- geometry/matrix diagnostics and assumptions.

### Acceptance

Check radial and placement geometry, units, conductor ordering, matrix conditioning, reciprocity/symmetry, passivity/positive-real behavior, frequency continuity, and reference comparisons.

### Limitations

Cable constants do not automatically provide cable ampacity, thermal transients, pulling tension, duct-bank derating, sheath-current optimization, short-circuit thermal withstand, aging, or installation design. Those remain separate study contracts unless implemented.

## Transformer-parameter conversion (`transformer_parameters`)

### Purpose

Convert transformer ratings, winding information, short-circuit/no-load tests, vector group, bases, taps, and related input into a consistent parameter/report representation and generated electrical branches.

### Required inputs

- transformer rating and frequency;
- winding ratings, connections, vector group, and ordering;
- short-circuit test impedances and losses with test basis;
- no-load current/loss where magnetizing data are required;
- temperature and tap position;
- unit and per-unit base convention;
- allocation assumptions for incomplete multiwinding test data.

### Outputs

- winding/branch resistance and leakage quantities;
- ratios and base conversions;
- magnetizing branch quantities where supported;
- matrices or generated branch data;
- human-readable report;
- assumptions, warnings, and source metadata.

### Acceptance

Check base conversion, positivity, winding ordering, vector-group interpretation, reproduction of supplied tests, loss consistency, and transparent treatment of underdetermined allocation.

### Limitations

Parameter conversion is not a complete transformer design, thermal, insulation, inrush, wideband, protection, or manufacturer-certification study. It does not create missing test data.

# Planned study domains

The current catalog also declares planned interfaces across the domains below. Their presence supports architecture and data planning; it is not a statement that numerical results are available.

## Static network analysis

Includes balanced and unbalanced AC power flow, DC power flow, voltage drop, load allocation, voltage stability, contingency screening, hosting capacity, and optimal power flow.

Before implementation, each study requires:

- network/asset schemas and phase conventions;
- bus type and control policy;
- initialization and convergence behavior;
- limits and infeasibility reporting;
- typed quantities, bases, assumptions, and warnings;
- benchmark systems and independent validation.

## Fault analysis

Includes short-circuit, IEC-style and ANSI-style calculations, unbalanced faults, and DC faults.

Implementation must distinguish standard/method revision, prefault assumptions, voltage factors, sequence/phase data, grounding, source contribution, machine/converter treatment, asymmetry, peak/interrupting duty, and equipment-rating comparison.

No result should be labeled IEC or ANSI compliant without an implemented, reviewed method and traceable standard basis.

## Protection

Includes protection coordination, relay settings, time-current coordination, fuse/recloser coordination, distance protection, differential protection, and settings optimization.

Required future contracts include relay characteristic provenance, CT/VT data, pickup/time settings, operating quantities, zones, communication logic, breaker clearing, tolerances, selectivity margins, and plotted/structured coordination evidence.

## Arc flash, grounding, and safety

Includes arc flash, labels, grounding-grid design, step/touch voltage, grounding-conductor sizing, and lightning/surge risk screening.

These are safety-critical. Implementation requires explicit standard/method editions, working distances, enclosure/electrode configuration, protective-device clearing, soil model, fault-current distribution, uncertainty, labels/reports, and independent verification. A generic transient result is not an arc-flash or grounding study.

## Dynamic and transient-stability studies

Includes RMS transient stability, switching/lightning transients, transformer inrush, motor starting, ferroresonance, and insulation coordination.

Some physical phenomena can already be represented through specific EMT cases, but that does not make every separately named study workflow implemented. A production study requires its own input, orchestration, result, and qualification contract.

## Power quality and harmonics

Includes harmonic load flow, harmonic resonance, filter sizing, flicker, voltage sag/swell, and voltage unbalance.

Implementation requires spectrum/source definitions, frequency-dependent network data, aggregation and diversity policy, standards/reporting basis, resonance metrics, time aggregation, and uncertainty. An FFT of one waveform is not automatically a harmonic-load-flow or compliance study.

## Machines

Includes induction/synchronous machine workflows, generator capability/loading, motor torque-speed, machine thermal, and excitation/governor studies.

Executable EMT machine models already exist for declared products, but system-level sizing, capability, thermal, or standardized workflows remain separate maturity claims.

## Renewables, converters, and storage

Includes PV string/inverter/cable sizing, PV yield, grid-following and grid-forming studies, BESS sizing, storage dispatch, wind-turbine models, and ride-through checks.

Switch-detailed and control cases do not by themselves establish a complete renewable-plant, energy-yield, storage-sizing, or grid-code compliance workflow.

## Thermal and mechanical cable studies

Includes ampacity, dynamic rating, overload capacity, short-circuit withstand, pulling, and installation derating.

These require thermal/material/installation models, environmental boundary conditions, standard basis, and uncertainty separate from the cable electrical-constants calculation.

## Equipment sizing

Includes conductor, transformer, generator, motor, switchgear, CT/VT, UPS/battery, grounding-conductor, and other sizing workflows.

Sizing must combine electrical duty, thermal/mechanical constraints, standard margins, operating scenarios, and explicit selection criteria. It must not be inferred from a single nominal load-flow or fault value.

## Optimization and planning

Includes feeder reconfiguration, capacitor placement, DER placement/sizing, cable-sizing optimization, storage dispatch, protection optimization, and related planning.

An optimization result must define objective, variables, constraints, scenarios, solver status, optimality/gap, infeasibility behavior, and sensitivity. A numerical candidate without a feasible engineering verification is not an accepted design.

## Reliability and aging

Includes reliability indices, outage impact, asset aging, transformer loss of life, and cable thermal aging.

Implementation requires failure/repair data provenance, network state model, uncertainty, load/environment histories, thermal/aging standards or equations, and reproducible scenario/Monte Carlo policy.

# Study input and result interfaces

## Run request

A run request identifies the study and optionally a case path and output directory. Production orchestration should additionally capture the revision, environment, solver policy, and output selection.

## Typed result

A study result contains:

- study identifier;
- status: `ok`, `warning`, `failed`, `not_implemented`, or `invalid_input`;
- quantities keyed by stable symbols, each with value, unit, optional base, and description;
- assumptions;
- warnings with code, severity, and message;
- metadata.

An `ok` result with a noninformational warning should be promoted to a warning state. Callers must inspect status and warnings rather than assuming any returned object is acceptable.

## Validity assessment

Scientific model contracts can bind requested fidelity and numerical/physical domain quantities. A validity assessment identifies missing quantities, wrong types, nonfinite values, bounds violations, and fidelity mismatch. The caller can reject the request through a typed validity-domain error.

# Adding a new study

A new descriptor should not be marked implemented until the repository contains:

1. a stable study ID, name, domain, and source owner;
2. input schema with units, bases, signs, and provenance;
3. validation and validity-domain rules;
4. deterministic orchestration and solver binding;
5. typed result quantities, assumptions, warnings, and metadata;
6. explicit failure and not-implemented behavior;
7. independent or analytical verification;
8. at least one runnable public case where licensing allows;
9. regression/qualification tests;
10. complete user documentation and release note.

The generated catalog makes all descriptors visible and prevents roadmap items from being omitted from documentation. Maturity remains the boundary between visibility and a supported numerical claim.
