# AIMORAResources

`AIMORAResources` is the canonical public owner for AIMORA cases, catalogues, independent reference models, documentation, report templates, teaching material, provenance, and redistributable scientific-reference content.

## Repository map

| Path | Purpose |
| --- | --- |
| `AIMORACases/` | Versioned executable public examples and case catalogue |
| `AIMORACatalogs/` | Public engineering catalogues and catalogue APIs |
| `AIMORAReferenceModels/` | Independent public analytical/manufactured reference models |
| `symbol-collections/` | Searchable system, user, and project symbol-collection manifest pinned to the canonical Platform grammar |
| `docs/` | Documenter-based professional user, engineering, and developer manual |
| `report-templates/` | Versioned declarative report profiles and licence metadata |
| `examples/reporting/` | Public semantic-reporting fixtures and claim boundaries |
| `provenance/` | Source, transformation, and rights records |
| `references/` | Tracked redistributable reference source and exact external-package pins |
| `teaching/` | Teaching material and lawful educational assets |

## Professional documentation

Start at:

```text
docs/src/professional-manual.md
```

The manual covers architecture, accepted public model families with planned boundaries labelled, implemented and planned studies, deck-card families, registered cases through their canonical per-case READMEs, solver availability and diagnostics, result interpretation, semantic reporting, troubleshooting, source coverage, and terminology.

Build and check it with:

```bash
julia --startup-file=no docs/check_content.jl
make -C docs build
```

## Public cases

`AIMORACases/examples/catalog.toml` is the machine-readable case index. Each released case owns a substantive README, Julia entry point, input, local Makefile, canonical outputs, and provenance.

```bash
cd AIMORACases
make check
make test
make example
```

Run one case:

```bash
make -C AIMORACases/examples/emt/rlc_energization run
```

The engine repository intentionally does not duplicate examples.

## Report templates

The versioned template inventory is:

```text
report-templates/v1/manifest.toml
```

Profiles cover general engineering, reproducible research, qualification, education, EMT, line/cable constants, transformer parameters, and combined reports. Templates own structure and required semantic roles, not engineering equations or result transformations.

## Reporting example

`examples/reporting/complete_report/` documents the complete typed-result-to-publication lifecycle implemented by `AIMORAPlatform/AIMORAReporting`. Its manufactured fixture validates reporting behavior only and is not a numerical-solver qualification claim.

## Scientific and rights boundary

- Public cases and references must be lawfully redistributable.
- Restricted source material remains outside the tracked public tree and is integrity-pinned where permitted.
- Examples use AIMORA Julia APIs; compiled historical programs and private oracle data are not runtime dependencies.
- A public example demonstrates a declared case, not universal compatibility or certification.
- Publisher-, standard-, client-, manufacturer-, logo-, font-, and artwork-specific templates require exact rights and compatibility evidence.

## Licence

AIMORA-authored content is distributed under the PolyForm Noncommercial License 1.0.0 unless a path identifies different terms. Research, education, personal study, public-interest noncommercial use, and other purposes permitted by that licence are free. Commercial use requires a separate written agreement with Ahmed Elkholy <ahmed_elkholy@f-eng.tanta.edu.eg>. Third-party material retains its own terms.
