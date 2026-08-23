# Architecture

## Ownership boundary

```text
AIMORA.jl
├── core, models, studies, I/O       public engineering interfaces
└── numerical backend boundary       separately distributed capability

BPAEMTPReference.jl                  public historical reference
AIMORACases                       public canonical cases
AIMORACatalogs                    public model data
```

Public APIs define typed inputs, state ownership, study orchestration, and
physical results without exposing distribution internals.

## Numerical backends

CPU execution is the portable baseline. Existing CUDA batching is an optional,
validated path rather than the architecture boundary. Additional GPU families
should use backend-neutral Julia kernels where measurement supports them, with
explicit capability detection and CPU fallback. “Any GPU” is not claimed
until AMD, Intel, Apple, and other selected backends have individual tests.

## Package layers

1. Deck and project intake validates physical data and units.
2. Typed domain models own assets and study-specific facets.
3. Study orchestration selects validated numerical owners.
4. Solvers mutate explicit state and produce physical results.
5. Reporters export quantities with units, bases, and assumptions.

The GUI must consume these APIs rather than creating a second model schema.
