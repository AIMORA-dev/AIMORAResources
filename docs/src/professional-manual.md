# AIMORA Professional User Manual

This manual is the canonical user-facing entry point for AIMORA’s public engineering platform. It is organized by workflow rather than repository internals and is intended to provide the same kinds of answers engineers expect from mature simulation products: what a model represents, which study can use it, which data are required, how to run a case, which results are produced, how to judge numerical quality, and where the validity limits are.

## Documentation map

| Need | Reference |
| --- | --- |
| Install and initialize an authorized workspace | [Getting started](getting-started.md) |
| Understand package and private/public boundaries | [Architecture](architecture.md) and [Architecture reference](architecture-reference.md) |
| Select a study and confirm whether it is implemented | [Study reference](study-reference.md) |
| Select an accepted electrical or control model and identify planned boundaries | [Model reference](model-reference.md) |
| Author or audit an AIMORA input deck | [Deck-card reference](deck-card-reference.md) |
| Run public examples and understand their outputs | [Example catalogue](example-catalog.md) |
| Activate and diagnose the production backend | [Solver reference](solver-reference.md) |
| Interpret tables, waveforms, residuals, and manifests | [Results and reporting](results-and-reporting.md) |
| Resolve installation, data, convergence, and publication failures | [Troubleshooting](troubleshooting.md) |
| Audit documentation completeness | [Source coverage](source-coverage.md) |
| Look up AIMORA terminology | [Glossary](glossary.md) |

## Product status rule

AIMORA distinguishes **implemented**, **planned**, **prototype**, and **legacy-reference** study contracts. A parser type, source file, catalogue row, attractive figure, or future interface does not prove that a study is executable. The current public study catalogue identifies these implemented study families:

- electromagnetic transients (EMT);
- overhead-line constants;
- cable constants and frequency scans;
- transformer-parameter conversion and branch generation.

Power flow, short circuit, protection, arc flash, grounding, harmonic, sizing, renewable-energy, optimization, reliability, and other study families remain planned unless a later accepted revision explicitly changes their status.

## Standard engineering workflow

1. **Identify the physical question.** Decide whether the required representation is instantaneous EMT, frequency-domain line/cable constants, transformer-parameter conversion, or a planned study that AIMORA must currently refuse.
2. **Choose the validity domain.** State frequency range, timestep, duration, phase representation, fidelity, initialization, event treatment, and applicable equipment assumptions.
3. **Create or select canonical input.** Use a versioned public case or an open-text project/deck. Do not duplicate the same physical asset in separate study files without an explicit mapping.
4. **Run readiness and parsing checks.** Invalid cards, missing units, unsupported components, contradictory topology, and unavailable solver capabilities must fail before numerical execution.
5. **Activate the authorized solver when required.** The public engine can load without the private backend. Production EMT execution requires explicit process-local activation.
6. **Execute the study.** Preserve exact project, scenario, study, solver, and result revisions.
7. **Review result quality.** Check convergence, KCL, energy balance, passivity, initialization residuals, timestep refinement, event localization, and deterministic restart as applicable.
8. **Generate a semantic report.** Bind the immutable typed result and render portable Markdown, HTML, JSON, TeX, CSV, SVG, or other admitted outputs without recomputing physics in a template.
9. **Freeze or revise.** A reviewed and approved report is frozen by content hash. Corrections create a new revision and supersede the prior publication.

## Running an example

From the initialized workspace:

```bash
make -C AIMORAResources/AIMORACases/examples/emt/rlc_energization run
```

A dynamic example normally writes a CSV time series, SVG waveform, and Markdown summary under its `outputs/` directory. Static examples write matrices, frequency scans, parameter tables, or text reports appropriate to the study.

## Documentation acceptance boundary

Every public model family, implemented study family, deck-card family, solver-facing public contract, result family, and registered example must be reachable from this manual or from the canonical README stored beside the executable case. Private solver algorithms and restricted qualification evidence are documented only at their public behavioral boundary.
