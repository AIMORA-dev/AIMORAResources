# AIMORACases.jl

`AIMORACases.jl` is the canonical source of public AIMORA examples and benchmark inputs. Documentation, package tests, and qualification systems should consume versioned cases instead of maintaining copies.

## Organization

```text
examples/
  catalog.toml
  emt/                    runnable EMT examples and their input decks
  line_constants/         line studies and their input decks
  cable_constants/        cable studies and their input decks
  transformer_parameters/
  support/
src/                      catalog API
test/                     catalog contract tests
check.jl                  structure and publication-boundary check
Makefile                  check, test, and example commands
```

Every catalog row declares its study, description, solver requirement, and compiled-reference compatibility. Each input deck lives beside the Julia `run.jl` that consumes it, so there is no second `cases/` copy to keep in sync. Future power-flow, fault, protection, dynamic, and optimization examples should be added only with an executable study consumer.

The source-to-example inclusion and exclusion audit is documented in [`examples/SOURCE_COVERAGE.md`](examples/SOURCE_COVERAGE.md) and enforced from the machine-readable `examples/source_coverage.toml` inventory.

```julia
using AIMORACases

AIMORACases.available_cases()
AIMORACases.case_path(:emt_rlc_energization)
```

The engine repository intentionally contains no examples. Run `make check`, `make test`, and `make example` before publishing a case revision. The `example` target runs the catalog listing and every registered EMT example. Individual study examples also use their local `Makefile`, for example:

```bash
cd examples/emt/inverter
make run
```

Input decks are data, not Fortran source: Julia parses them into typed AIMORA models and executes them through the public engine. An example adapted from another source must add its own provenance and redistribution licence before publication.

## Licence

This repository's AIMORA-authored content is distributed under the PolyForm Noncommercial License 1.0.0. Research, education, personal study, public-interest noncommercial use, and other purposes permitted by that licence are free; commercial use requires a separate written agreement with Ahmed Elkholy <ahmed_elkholy@f-eng.tanta.edu.eg>. There is no licence key, activation, telemetry, or technical feature restriction. Clearly identified third-party material retains its own terms, and copies received under an earlier licence retain those prior grants.
