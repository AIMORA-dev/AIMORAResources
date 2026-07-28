# AIMORACases.jl

`AIMORACases.jl` is the canonical source of public AIMORA examples and
benchmark inputs. Documentation, package tests, and private Julia-versus-
Fortran validation should consume these cases instead of maintaining copies.

## Organization

```text
cases/
  emt/
  line_constants/
  catalog.toml
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

Case inputs and package code are available under the MIT licence. A case that
comes from another source must add its own provenance and redistribution
licence before publication.
