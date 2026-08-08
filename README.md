# BPAEMTPReference.jl

`BPAEMTPReference.jl` packages the historical Bonneville Power Administration Electromagnetic Transients Program as an external compiled reference for AIMORA. It is not part of AIMORA's production Julia simulation loop.

The repository contains:

- the preserved fixed-form Fortran sources;
- a portability preprocessor and reproducible `gfortran` build;
- a small Julia wrapper for building and running reference decks;
- runnable reference examples;
- an executable package/provenance check.

```text
src/fortran/                         preserved historical sources
src/julia/                           portability preprocessing
src/BPAEMTPReference.jl              public Julia wrapper
scripts/                             reproducible reference build
examples/emt/rlc_energization/       compiled-Fortran reference example
test/                                wrapper and optional compiled tests
check.jl                             source, provenance, and package checks
Makefile                             check, build, test, and example commands
```

## Build and run

```julia
using BPAEMTPReference

BPAEMTPReference.build_reference()
result = BPAEMTPReference.run_deck(
    read("examples/emt/rlc_energization/rlc_energization.deck", String);
    output_dir = "examples/outputs",
)
```

The build requires Julia, Bash, and `gfortran`. The wrapper uses the instrumented `-O0` reference build because the historical source relies on legacy storage and evaluation behavior that is not safe under modern compiler optimization.

Equivalent shell commands are available through `make check`, `make build`, `make test`, and `make example`.

## Production boundary

This package is an oracle. `AIMORA.jl` must never call it from a production study, solver, timestep, or report path.

## Licensing and provenance

The AIMORA-authored Julia wrapper, portability, build, test, and documentation files are distributed under the PolyForm Noncommercial License 1.0.0. Research, education, personal study, public-interest noncommercial use, and other purposes permitted by that licence are free; commercial use requires a separate written agreement with Ahmed Elkholy <ahmed_elkholy@f-eng.tanta.edu.eg>. Copies received under the earlier MIT licence retain those prior grants.

The historical BPA source retains its original notices. `MAIN00.FOR` states that BPA disseminated the program materials freely under its long-standing policy and the Freedom of Information Act, without warranty. See `LEGACY-NOTICE.md`; the AIMORA wrapper licence does not replace those historical notices.
