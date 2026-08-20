# Troubleshooting

Use this guide from the first failing boundary. Do not change numerical tolerances, replace models, or delete evidence until the failure class is identified.

## Workspace initialization

### Submodule is empty or detached

**Symptoms**

- component directory is empty;
- `bin/aimora doctor` reports an uninitialized component;
- a child repository is on a detached revision when editing is expected.

**Checks**

```bash
bin/aimora status
bin/aimora init
bin/aimora doctor
```

Confirm that the authenticated identity can read every private gitlink. The workspace pins exact revisions; do not replace a missing private child with an unrelated public package.

### Wrong origin

The workspace launcher validates canonical fetch and push identities. A personal fork may be used on a feature branch, but publication must state the fork and upstream explicitly. Do not make a fork-only commit the permanent organization gitlink before the upstream PR is accepted.

## Julia/package loading

### Package not found

Run the example from its documented package environment or set the public engine path:

```bash
julia --project=AIMORAResources/AIMORACases.jl -e 'using Pkg; Pkg.instantiate()'
```

A public example loader searches the workspace sibling or installed package. It does not download arbitrary code at runtime.

### Incompatible Julia version

AIMORA public packages declare Julia 1.10 compatibility. Use a supported Julia version and regenerate only local manifests; do not commit a workstation-specific manifest unless the repository explicitly owns it.

## Solver activation

### `SolverUnavailableResult` or no active backend

The public engine is working, but production numerical execution is not activated.

```julia
using AIMORA, AIMORASolvers
AIMORA.activate_solver!(AIMORASolvers.production_backend())
AIMORA.solver_status()
```

### Capability missing

Inspect the backend capability list. A missing capability is not solved by renaming the study or requesting a lower fidelity. Select an implemented capability or stop with the typed readiness error.

## Parsing and readiness

### Unknown card

Confirm the active syntax profile, card family, spelling, field widths, and section. An unknown card is never interpreted by similarity.

### Continuation rejected

A continuation must immediately follow a compatible owner record and satisfy its field schema. Check accidental blank records, comments, and case boundaries.

### Node or component reference missing

Resolve the exact identifier and phase/terminal mapping. Fixed-field whitespace and case may be significant.

### Missing unit or base

State the engineering unit and per-unit base explicitly. Do not insert a guessed base to make the parser pass.

## Initialization failures

### Large initial residual

Check:

- contradictory initial voltages/currents/fluxes;
- infeasible switch state;
- machine operating point and mechanical torque;
- residual transformer flux;
- control integrator/limiter state;
- line/cable history initialization;
- source phase and reference convention.

A study may admit a declared startup transient, but it must not label an inconsistent state as steady initialization.

## Linear solve failures

### Singular nodal matrix

Common causes:

- island without reference;
- ideal voltage-source/constraint conflict;
- duplicate ideal constraints;
- all-open topology;
- zero impedance where an explicit ideal constraint is required;
- incorrect terminal numbering.

Inspect the reported node/component context before adding artificial conductance.

### Poor conditioning

Check units, extreme parameter ratios, scaling, and topology. Artificial damping changes the model and must not be introduced silently.

## Nonlinear convergence

### Residual does not decrease

Check device domain, Jacobian/residual consistency, scaling, limit transitions, event location, initial guess, and timestep. Review the component-level diagnostic rather than increasing iteration limits first.

### Chatter around a discontinuity

Confirm event hysteresis/debounce, exact priority, zero-crossing rule, and rollback. The solver should localize the event or issue a bounded warning; it must not loop indefinitely.

## EMT result problems

### Peak disappears from the figure

Use event-preserving downsampling and verify the CSV/full-resolution trace. The report renderer preserves declared events and local extrema; a third-party plot may not.

### KCL or energy residual spikes

Short spikes may coincide with ideal events, but their interpretation must follow the model contract. Persistent residuals suggest incorrect stamping, state acceptance, sign convention, or output reconstruction.

### Restart differs from uninterrupted run

Verify snapshot schema/revision, all model/control/event/history states, output cursor, and exact split boundary. Any omitted state invalidates deterministic replay.

## Line/cable constants

### Nonphysical matrix or negative/passivity result

Check conductor ordering, geometry, material data, earth return, sheath/bonding, unit conversions, and frequency. Inspect conditioning before applying a transformation.

### Fitted line unstable outside the sample band

A fit is valid only over its declared band and extrapolation policy. Review poles, delays, passivity certificate/enforcement, weighting, and uncertainty. Do not use out-of-band behavior as an engineering result.

## Transformer parameters

### Test reconstruction does not match

Check winding order, connection, base MVA/voltage, referred side, test temperature, loss convention, and whether the supplied tests are mutually sufficient. Non-identifiable parameters must remain reported as such.

## Reporting

### Report provider missing

The study may be planned or its provider has not been accepted. Do not substitute a generic template that invents claims. Register a provider only with a typed result and minimum useful report matrix.

### QA blocks publication

Read each issue code. Typical blockers are invalid result hashes, missing mandatory sections, malformed table shape/type, NaN/Inf, invalid log axes, missing figure accessibility text, dependency cycles, unresolved review comments, or stale approval.

### PDF unavailable

Portable TeX and other outputs can still be generated. Install and lock the admitted Tectonic profile only when PDF is required. Missing TeX is a toolchain diagnostic, not a reason to alter report semantics.

### Frozen report changed

A frozen report is immutable. Create a new revision with `supersedes`, review it, approve it, and freeze it. Do not overwrite the prior manifest or PDF.

## Documentation checks

```bash
julia --startup-file=no AIMORAResources/docs/check_content.jl
make -C AIMORAResources/docs build
```

Failures identify missing manual pages, uncovered cases, missing templates, broken local links, or documentation claims that exceed the implemented study catalogue.

## What to include in an issue

Provide:

- exact repository and commit revisions;
- operating system and Julia version;
- public case ID or minimal redistributable input;
- full typed diagnostic, not only a screenshot;
- command used;
- expected and actual behavior;
- whether the solver was active;
- result/report manifest hashes;
- any private/restricted material removed or replaced with a lawful fixture.
