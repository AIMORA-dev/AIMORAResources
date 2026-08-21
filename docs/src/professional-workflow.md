# Professional Engineering Workflow

AIMORA projects should be treated as controlled engineering analyses, not as isolated scripts. A reproducible study records the software revision, input provenance, model fidelity, validity domain, solver policy, events, output contract, diagnostics, and acceptance evidence.

## 1. Establish the analysis question

Write the decision or phenomenon before selecting a model. Examples include:

- maximum transient recovery voltage after capacitor-bank interruption;
- current and DC-link response of a switching converter during a voltage sag;
- frequency-dependent impedance of an overhead line or cable;
- transformer inrush and core-flux trajectory;
- machine torque, speed, slip, and control response after an event;
- deterministic replay of an EMT case from a checkpoint.

The question determines the required study, bandwidth, simulation horizon, timestep, model fidelity, outputs, and validation evidence. A detailed model is not automatically a better model when its parameters are unavailable or its validity domain does not match the problem.

## 2. Record the execution environment

Use isolated Julia projects and retain exact public repository revisions.

```bash
git clone https://github.com/AIMORA-dev/AIMORA.jl.git
git clone https://github.com/AIMORA-dev/AIMORAResources.git
julia --project=AIMORA.jl -e 'using Pkg; Pkg.instantiate()'
```

For a Resources-only documentation checkout, place `AIMORA.jl` beside `AIMORAResources` or set:

```bash
export AIMORA_DOCS_ENGINE_PATH=/absolute/path/to/AIMORA.jl
```

Record at least:

| Item | Required record |
|---|---|
| Repository set | Exact commit SHA for every public repository used |
| Engine revision | Exact `AIMORA.jl` SHA |
| Solver revision | Exact authorized solver SHA when used |
| Resources revision | Exact case/catalog/documentation SHA |
| Julia environment | Julia version plus `Project.toml` and `Manifest.toml` |
| Host | OS, architecture, CPU, optional GPU, and thread count |
| Run policy | Timestep, horizon, tolerances, event calendar, random seed |

Never describe a run as reproducible when it depends on an unrecorded local checkout or floating branch.

## 3. Select a study by maturity

Inspect the generated [Complete Study Catalog](generated/study-catalog.md). The maturity field is normative:

- `implemented` means the study has a callable execution route for its declared supported domain;
- `prototype` means the interface is experimental and may change;
- `planned` means only a typed roadmap contract exists;
- `legacy_reference` is retained for comparison or historical qualification, not as the production timestep loop.

A planned descriptor must return a transparent `not_implemented` result. It must never fabricate values or silently substitute another study.

## 4. Select model fidelity

Use the [Model Library](model-reference.md) and generated [Model Declaration Index](generated/model-index.md).

For each selected model, document:

1. **Physical purpose** — what equipment or phenomenon it represents.
2. **Fidelity** — lumped, travelling-wave, frequency-dependent, switching-detailed, average-value, magnetic-equivalent, machine electromagnetic, or another declared level.
3. **Required inputs** — values, units, base quantities, orientation, and provenance.
4. **Dynamic state** — differential, algebraic, discrete, delayed-history, scheduler, and random state.
5. **Validity domain** — frequency, voltage, timestep, geometry, parameter positivity, topology, and unsupported phenomena.
6. **Initialization** — zero state, steady state, calculated state, imported state, or checkpoint restoration.
7. **Outputs** — typed quantities, units, signs, bases, and diagnostic residuals.
8. **Evidence** — analytical reference, manufactured solution, historical reference, cross-model comparison, regression case, or measured data.

Do not invent missing detailed parameters. Either obtain the data, use an explicitly simpler model, or stop the study and report the gap.

## 5. Prepare engineering data

### Units and bases

AIMORA interfaces distinguish absolute SI quantities from per-unit or normalized values. Every per-unit value requires its base. Every phasor or signed quantity requires an orientation or reference convention.

Recommended conventions:

| Quantity | Preferred unit | Required clarification |
|---|---|---|
| Voltage | V | phase-to-ground, phase-to-phase, RMS, peak, or instantaneous |
| Current | A | positive direction and RMS, peak, or instantaneous |
| Resistance | Ω | temperature and frequency where relevant |
| Inductance | H | phase, sequence, leakage, mutual, or matrix definition |
| Capacitance | F | phase, sequence, shunt, mutual, or matrix definition |
| Power | W / var / VA | sign convention and averaging window |
| Energy | J | integration boundary and positive direction |
| Frequency | Hz | fundamental, sample, carrier, or fit frequency |
| Time | s | event alignment and scheduler grid |
| Speed | rad/s or pu | mechanical/electrical and base speed |
| Torque | N·m | positive mechanical direction |

### Provenance

Each material parameter should identify its source, transformation, uncertainty, validity domain, and scientific role. Separate physical parameters from scaling bases and numerical policies. A timestep or convergence tolerance is not a physical equipment parameter.

### Data-quality gate

Before execution, reject:

- missing required fields;
- non-finite values;
- negative or zero values where the model requires positivity;
- incompatible matrix dimensions;
- events outside the simulation horizon;
- event times that violate an exact scheduler calendar;
- inconsistent bases or units;
- unsupported topology or phase count;
- requests outside a declared validity domain.

## 6. Build or select a case

The canonical public cases live in `AIMORACases.jl/examples`. Locate a suitable case in the generated [Complete Runnable Case Catalog](generated/case-catalog.md).

A professional case directory should contain:

```text
case-directory/
├── README.md          purpose, model, assumptions, run command, outputs, interpretation
├── Makefile           deterministic local entrypoint
├── run.jl             orchestration and acceptance checks
├── *.deck / *.toml    reusable engineering input where applicable
└── outputs/           curated results or regenerated artifacts
```

When adapting a case:

- copy it under a new case identifier rather than overwriting benchmark evidence;
- preserve the original source identifier and describe every change;
- update units, bases, topology, event calendar, and acceptance thresholds together;
- keep input data separate from execution code;
- never edit committed expected output merely to make a failing comparison pass.

## 7. Configure numerical execution

The production solver policy depends on the selected study and model. For EMT work, document:

- fixed-step policy; an adaptive policy may be recorded only after an explicitly accepted adaptive capability is selected;
- total simulation horizon;
- event localization and collision ordering;
- linear and nonlinear convergence tolerances;
- maximum nonlinear iterations and fallback behavior;
- history-buffer and travelling-wave delay treatment;
- control sample, computational delay, hold, PWM, and protection calendars;
- checkpoint and restart locations;
- CPU or optional GPU backend.

The solver must not silently relax tolerances, drop an event, replace a model, or continue after a failed nonlinear solve without issuing a typed warning or failure.

## 8. Run deterministically

Use the case Makefile when provided:

```bash
make -C AIMORACases.jl/<case-directory> run
```

For package tests:

```bash
julia --project=AIMORA.jl -e 'using Pkg; Pkg.test()'
julia --project=AIMORACases.jl -e 'using Pkg; Pkg.test()'
```

A run record should capture stdout/stderr, process exit code, elapsed time, revision metadata, and the output directory. A successful exit code is only the first gate.

## 9. Review results

Use [Results and Validation](results-and-validation.md). At minimum, inspect:

- requested engineering quantities with units and signs;
- event occurrence and event ordering;
- warnings and assumptions;
- KCL or nodal residuals;
- energy or power-balance residuals;
- passivity and stability diagnostics where applicable;
- nonlinear convergence history;
- frequency-fit error and passivity corrections for wideband models;
- checkpoint/restart equivalence;
- comparison against analytical, reference, regression, or measured evidence.

Visual plausibility is not acceptance evidence. A smooth waveform can still contain a wrong sign, wrong base, missing event, unstable fit, or energy-creating model.

## 10. Report the case

A technical report should include:

1. objective and decision supported;
2. system boundary and single-line/topology description;
3. software and data revisions;
4. study and model selection rationale;
5. complete input table with provenance;
6. numerical policy and event calendar;
7. requested outputs and sign conventions;
8. results with units and analysis windows;
9. validation evidence and quantitative residuals;
10. warnings, limitations, unsupported phenomena, and uncertainty;
11. exact reproduction command.

Do not label a result as standards-compliant, manufacturer-validated, certified, or field-validated unless the corresponding evidence is actually present.

## 11. Change control

Any change to a model, parser, solver, case, or catalog that can affect results requires:

- an updated scientific contract or documentation statement;
- a focused unit or manufactured-solution test;
- at least one executable case;
- regression review of affected outputs;
- refreshed generated reference pages;
- a release note when user-visible behavior changes.

The documentation generator makes new source owners, model declarations, parser declarations, study descriptors, and cases visible automatically. Their appearance in an inventory is not enough: maintainers must add the engineering explanation and evidence required by this manual.
