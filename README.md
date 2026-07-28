# AIMORACatalogs.jl

`AIMORACatalogs.jl` provides open, versioned equipment data for AIMORA. Each
asset has common nameplate data and separate study facets, allowing a GUI to
show ETAP-style tabs without duplicating scientific definitions.

```julia
using AIMORACatalogs

transformer = asset(:generic_transformer_10mva)
study_tabs(transformer)
study_facet(transformer, :power_flow)
```

The initial entries are explicitly synthetic examples. Manufacturer and
commercial data may be added only when its provenance and redistribution
licence are recorded. AIMORA must not imply manufacturer certification or
silently substitute missing study parameters.

Catalog code and the included synthetic data are available under the MIT
licence.

## Structure and checks

```text
catalogs/generic/      versioned synthetic equipment data
src/                   catalog and study-facet API
test/                  provenance and facet tests
examples/              public catalog example
check.jl               structure and publication-boundary check
Makefile               check, test, and example commands
```

Run `make check`, `make test`, and `make example` before publishing catalog
changes.
