# AIMORACases.jl

`AIMORACases.jl` is the canonical source of public AIMORA examples and
benchmark inputs. Documentation, package tests, and qualification systems
should consume versioned cases instead of maintaining copies.

## Organization

```text
cases/
  emt/
  line_constants/
  catalog.toml
src/                  catalog API
test/                 catalog contract tests
examples/list_cases.jl public discovery example
examples/emt/          runnable EMT examples grouped by capability
check.jl              structure and publication-boundary check
Makefile              check, test, and example commands
```

Every catalog row declares its study, description, solver requirement, and
compiled-reference compatibility. Future power-flow, fault, protection,
dynamic, and optimization cases should be added only with an executable study
consumer.

```julia
using AIMORACases

AIMORACases.available_cases()
AIMORACases.case_path(:emt_rlc_energization)
```

The engine repository intentionally contains no examples. Run `make check`,
`make test`, and `make example` before publishing a case revision. The
`example` target runs the catalog listing and every registered EMT example.
Individual study examples also use their local `Makefile`, for example:

```bash
cd examples/emt/inverter
make run
```

Case inputs and package code are available under the MIT licence. A case that
comes from another source must add its own provenance and redistribution
licence before publication.
