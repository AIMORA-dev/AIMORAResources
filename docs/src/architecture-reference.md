# Architecture Reference

## Repository ownership

AIMORA is a coordinated multi-repository system. Each semantic responsibility has one canonical owner.

| Repository | Responsibility |
| --- | --- |
| `AIMORA.jl` | Public engine, typed study/model/result contracts, open models, parsers, study orchestration, reports at the engine compatibility boundary |
| `AIMORASolvers.jl` | Private production numerical backend, nodal/nonlinear kernels, timestep orchestration, accelerator integration |
| `AIMORAValidation` | Private qualification, benchmarks, independent oracles, receipts, release evidence |
| `AIMORAPlatform` | Project, format, layout, service, visual, reporting, and symbol packages |
| `AIMORAResources` | Public cases, catalogues, independent reference models, documentation, templates, teaching, provenance, redistributable reference material |
| `AIMORAStudio` | Browser, desktop, and VS Code clients; TypeScript presentation and protocol clients only |
| `AIMORAWorkspace` | Governance, launchers, reviewed gitlinks, exact revision coordination, and ignored external-reference routing |

The workspace root does not own copies of child source, example decks, generated evidence, or documentation content.

## Public/private solver boundary

The public engine defines `AbstractAIMORASolverBackend`, capability metadata, typed unavailable results, state snapshot/restore contracts, and study execution entry points. The private solver implements those contracts. Public code must not contain the private repository URL, private source files, private arrays, or assumptions about the solver’s internal sparse storage.

Activation is explicit and process-local:

```julia
using AIMORA
using AIMORASolvers

AIMORA.activate_solver!(AIMORASolvers.production_backend())
AIMORA.solver_status()
```

A public-only installation remains usable for schemas, validation, catalogues, open models, and public interfaces. A production solve without an activated backend returns a typed unavailable result or raises the documented capability error; it does not silently substitute a lower-fidelity calculation.

## Data flow

```text
Canonical project or deck
    → strict parse and validation
    → typed study definition
    → explicit study realization
    → selected backend capability
    → immutable typed result
    → validation and evidence
    → semantic visual/report model
    → renderer-specific artifacts
```

A renderer never becomes part of the numerical study. Loading AIMORA studies does not require HTML, SVG, Makie, TeX, or PDF tooling.

## Revision and dependency rules

Every reusable result identifies:

- project and project revision;
- scenario and study IDs;
- study settings and representation;
- solver and package revisions;
- units and bases;
- assumptions, warnings, and validity domain;
- upstream result hashes;
- payload hash.

Any change that affects the result signature invalidates dependent results. Cross-study reports expose the dependency DAG rather than flattening it into an untraceable narrative.

## Package dependency direction

The intended direction is:

```text
Formats → Project → Layout/Service/Visuals/Reporting
AIMORA public result contracts → Visuals/Reporting
Resources → consumes public packages for examples and documentation
Studio → consumes generated service/project/report contracts
```

Reporting and visualization may consume public typed results but must never be mandatory dependencies of a numerical study package.

## Scientific evidence boundary

Public examples demonstrate reproducible usage and declared behavior. Private qualification adds independent comparisons, mutations, refinements, performance evidence, external or laboratory evidence where applicable, and release receipts. A public example alone is not a certification or universal-validity claim.
