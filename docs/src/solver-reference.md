# Solver Reference

## Public solver contract

`AIMORA.jl` owns the public backend interface. A backend reports metadata and a typed capability inventory, prepares a study, executes it, and supports state snapshot/restore when the capability requires restart or rollback.

The public engine must load without the production backend. This allows schemas, project data, catalogues, open models, validation helpers, and planned interfaces to remain usable in public or teaching installations.

## Production activation

The public package can always inspect backend availability explicitly:

```julia
using AIMORA
AIMORA.solver_status()
```

An authorized backend distribution provides its own explicit activation call. Activation is process-local; it does not modify project data or install hidden global licence state, and the public packages never download or activate a licensed backend automatically.

## Advertised production capabilities

At the pinned solver revision the backend advertises typed capabilities for:

- time-domain EMT execution;
- EMT state snapshots;
- coupled-line frequency-domain fitting;
- coupled frequency-dependent line runtime;
- transformer/reactor apparatus execution;
- modern phase-domain electromechanical machine families.

The capability list is authoritative for admission. A study request that needs an absent capability must fail before execution.

## Numerical ownership

The activated backend owns:

- companion-form kernels;
- nodal/MNA assembly and solve;
- scaled nonlinear residual/Jacobian solve;
- topology and switching updates;
- timestep orchestration;
- rollback and checkpoint state;
- performance/accelerator integration.

Public equipment models own engineering identity, parameters, units, state semantics, readiness, and public results. Private storage layout is not part of the project or report schema.

## Fixed-step EMT execution

A typical step is:

1. establish the exact next boundary from timestep, event, and sampled-task schedules;
2. stamp linear companions and sources;
3. assemble nonlinear residual/Jacobian contributions;
4. solve nodal/MNA equations using declared scaling and tolerances;
5. localize or refine discontinuities when required;
6. accept component, control, machine, line-history, and measurement state;
7. emit typed outputs;
8. retain rollback/checkpoint information.

Rejected trials restore all continuous, discrete, history, event, task, and output state. Partial state acceptance is prohibited.

## Nonlinear convergence diagnostics

A nonlinear solve reports at least:

- iteration count;
- scaled residual norm;
- update norm;
- active constraints/limits;
- discontinuity or event context;
- failure component/node when available;
- timestep/refinement action;
- whether rollback was exact.

Failure does not produce a plausible-looking trace. The typed result records the failure boundary and admitted partial products, if any.

## Snapshot and restart

A valid snapshot includes every state required to reproduce continuation:

- component history sources;
- nonlinear internal state;
- line/cable delay and rational states;
- machine electrical/mechanical/control state;
- switch and event state;
- sampled-task clocks and held values;
- measurement/filter/channel state;
- output cursor and requested accumulators;
- solver/backend schema and revision identity.

Restoring an incompatible snapshot is refused. Exact split-run replay is a qualification requirement for capabilities that claim deterministic restart.

## CPU and accelerator behavior

CPU is the portable baseline. Optional acceleration is selected explicitly and must preserve the same declared fidelity, tolerances, result semantics, and deterministic-reduction contract. Hardware absence is not counted as a passing accelerator test. Crossover points are measured rather than assumed.

## Solver diagnostics

From a public contributor checkout:

```bash
julia --startup-file=no --project=AIMORA.jl -e 'using AIMORA; @show AIMORA.solver_status()'
julia --startup-file=no --project=AIMORA.jl -e 'using Pkg; Pkg.test()'
```

Common states:

| State | Meaning | Action |
| --- | --- | --- |
| public engine loaded; no backend | schemas and public APIs are available, production solve is unavailable | initialize/authorize the solver and activate it explicitly |
| backend activated; capability absent | installed backend does not implement the requested study/fidelity | select an admitted capability or stop; do not downgrade silently |
| source/runtime incomplete | a required public package or authorized backend component is missing | restore the exact supported distribution revisions |
| result nonconverged | numerical admission succeeded but solve criteria failed | inspect readiness, scaling, events, model domain, and timestep |
| snapshot incompatible | schema/revision/state inventory differs | restart from a compatible snapshot or initial state |

## Public safety boundary

Documentation describes solver behavior, interfaces, diagnostics, and acceptance criteria. It does not publish proprietary numerical source or private qualification data. Reports consume public typed results and metadata, never private arrays.
