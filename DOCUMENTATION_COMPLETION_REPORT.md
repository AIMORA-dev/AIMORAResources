# AIMORA Documentation Completion Report

## Scope

This branch replaces a navigation/theme-focused documentation effort with a professional engineering content system. The documentation is designed to remain complete as public models, parser cards, study descriptors, and registered cases evolve.

## Handwritten engineering manuals

The branch adds or substantially expands:

- installation and first-run guidance;
- controlled engineering workflow and reproducibility;
- complete model-family reference;
- study maturity and implemented/planned capability boundaries;
- deck/card parsing and validation reference;
- public solver integration, execution, diagnostics, failure, and restart behavior;
- result interpretation and validation hierarchy;
- troubleshooting guide;
- engineering glossary;
- public API guidance.

## Generated completeness inventories

`docs/generate_reference_pages.jl` regenerates four reference pages before every documentation check/build:

1. **Study catalog** — every typed descriptor, domain, maturity, and execution meaning.
2. **Model declaration index** — every public model source owner, concrete/abstract/enum declaration, declared field, and explicit export detected from the selected engine revision.
3. **Deck/card declaration index** — every public deck-parser owner and detected typed declaration/field/export.
4. **Case catalog** — every registered public case with purpose, study, input, entrypoint, result kind, solver/reference flags, evidence IDs, run command, interpretation, and acceptance guidance.

The case manual is generated from `AIMORACases.jl/examples/catalog.toml`; it does not invent numerical values. Case-local reports and committed output artifacts remain authoritative for actual results.

## Automated quality gate

`docs/content_audit.jl` and `docs/check.jl` enforce:

- all required professional chapters exist and are nontrivial;
- no placeholder text remains;
- every model source owner/declaration is represented;
- every deck/parser owner/declaration is represented;
- every study descriptor is represented;
- every registered case is represented and has required catalog fields;
- all Documenter navigation pages exist;
- local Markdown links resolve;
- obvious secret/token and machine-local path patterns are rejected.

The workflow `.github/workflows/ci.yml` resolves a public engine checkout, instantiates Julia environments, generates references, runs the content/link gates, builds Documenter with warnings treated as errors, and uploads the rendered manual plus generated inventories.

## Capability honesty

The documentation distinguishes:

- implemented studies;
- prototypes;
- planned interfaces;
- legacy reference paths.

Planned capabilities are documented for roadmap and input architecture only. They are not described as producing completed calculations.

The manual also distinguishes public scientific behavior from private production-backend implementation. It documents solver capability checks, responsibilities, diagnostics, and acceptance evidence without exposing private source or credentials.

## Numerical-result policy

No result is accepted solely because execution returned zero or a plot looks plausible. Case acceptance can require, as applicable:

- event occurrence and order;
- nonlinear convergence;
- KCL/nodal residual;
- power/energy balance;
- stability and passivity;
- fit accuracy over frequency;
- analytical/reference/measurement comparison;
- timestep or model-order sensitivity;
- checkpoint/restart equivalence.

Solver-required cases remain blocked when the authorized backend is unavailable; they are never silently marked as passing through a different numerical path.

## Build commands

From a workspace layout:

```bash
make -C AIMORAResources/docs instantiate
make -C AIMORAResources/docs generate
make -C AIMORAResources/docs check
make -C AIMORAResources/docs build
```

From a standalone Resources checkout:

```bash
make -C docs ENGINE_PATH=/absolute/path/to/AIMORA.jl build
```

## Branch policy

The work is isolated on `agent/matlab-grade-documentation`. The default branch is not merged by this documentation application. Review the branch build and generated artifact before merging.
