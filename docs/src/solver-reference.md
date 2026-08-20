# Solver and Execution Reference

AIMORA separates public scientific models, studies, cases, and result contracts from the authorized production numerical backend. This boundary allows the public documentation and validation evidence to describe behavior without exposing or coupling users to private implementation details.

## Public solver boundary

The public engine exposes three capability checks:

```julia
AIMORA.solver_available()
AIMORA.solver_status()
AIMORA.require_solver()
```

- `solver_available()` reports whether an authorized backend has registered successfully.
- `solver_status()` returns a stable machine-readable capability status.
- `require_solver()` returns the backend handle or throws a clear configuration error.

A public package import should not silently activate an unintended solver. Backend registration must be explicit and compatible with the public model/study contract.

## Installation and activation

The workspace is the preferred integration surface because it pins compatible engine, solver, cases, validation, platform, resources, and studio revisions.

```bash
git clone https://github.com/ahmelkholy/AIMORAWorkspace.git
cd AIMORAWorkspace
git submodule update --init --recursive
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Check availability:

```bash
julia --project=. -e 'using AIMORA; println(AIMORA.solver_status())'
```

When a case requires the production solver and no authorized backend is available, it should stop with a capability/configuration error or be marked **BLOCKED** by an execution harness. It must not substitute a reduced or historical solver without explicit user choice.

# Numerical responsibilities

Depending on the selected model/study, the backend can be responsible for the following categories.

## Nodal assembly

Models contribute conductance/admittance terms, history sources, injections, constraints, nonlinear residuals/Jacobians, and event-dependent topology. Assembly must preserve declared node/terminal ordering and orientation.

Required diagnostics include:

- matrix dimensions and sparsity;
- unresolved/floating nodes or islands;
- inconsistent ideal constraints;
- singular/ill-conditioned systems;
- scaling information where relevant;
- topology revision after events.

## Linear solution

A linear solve should expose enough metadata to distinguish:

- successful factorization and solution;
- singular matrix;
- numerical breakdown;
- dimension mismatch;
- unsupported backend/device;
- nonfinite inputs or outputs.

Caching/factorization reuse is valid only while the matrix structure and values satisfy the declared reuse conditions. A topology event or state-dependent Jacobian may require a rebuild.

## Nonlinear solution

Nonlinear devices and networks require a deterministic residual/Jacobian loop. Record:

- nonlinear method;
- scaled initial and final residual;
- iteration count and maximum;
- convergence tolerance;
- damping/line-search or limiting behavior;
- topology/event changes during the solve;
- failure or fallback reason.

The backend must not return the last iterate as a successful engineering solution after convergence failure.

## Dynamic companion models

Inductors, capacitors, machines, rational models, and other dynamic components contribute timestep-dependent equivalents and update physical/history state after an accepted solve.

A correct mutation order separates:

1. pre-step state snapshot;
2. event/control releases due at the current instant;
3. model assembly;
4. linear/nonlinear solve;
5. acceptance checks;
6. state/history commit;
7. output/report updates;
8. checkpoint creation when requested.

Rejected work must roll back atomically.

## Events and topology

Events can include switch operations, faults, clearance, current zero, gate transitions, sampled-control releases, protection actions, and scheduled case changes.

The execution policy must define:

- exact versus localized event time;
- ordering when multiple events share a timestamp;
- collision between electrical events and task releases;
- minimum separation/chatter prevention;
- topology rebuild requirements;
- rollback and retry behavior;
- occurrence reporting.

Requested and executed event times should be reported separately where they can differ.

## Travelling-wave and rational histories

Distributed and frequency-dependent models retain delay buffers, interpolation positions, rational state, modal transformation state, and possibly fit/passivity metadata. The runtime must update these in a deterministic order and include them in checkpoints.

## Multirate task scheduling

Control, sensing, estimation, modulation, protection, and reporting tasks can execute on different exact calendars. The scheduler should preserve:

- task dependency order;
- rational release times without floating-point drift;
- computational delay and hold semantics;
- collision policy;
- task state and pending events;
- deterministic checkpoint/restart.

## Optional accelerator execution

An optional GPU or other accelerator backend must preserve the scientific result contract. Acceleration should report device/backend selection and must not change units, signs, event ordering, convergence interpretation, or accepted tolerances silently.

CPU/GPU comparison should account for the declared numerical tolerance; bitwise identity must not be claimed unless it is explicitly guaranteed and tested.

# Solver selection

Use the simplest backend and fidelity that can answer the engineering question with the required evidence.

| Need | Solver characteristics |
|---|---|
| Linear lumped EMT | Sparse nodal solve plus companion histories |
| Nonlinear arrester/core/device | Residual/Jacobian iterations with limiting and convergence diagnostics |
| Switching topology | Deterministic event localization, topology rebuild, rollback |
| Travelling-wave line | Delayed-history buffers and interpolation |
| Rational wideband model | Stable real state-space update and passivity-aware diagnostics |
| Machines and controls | Coupled electromagnetic/mechanical state plus exact multirate scheduling |
| Switching converter | Fast electrical step, gate events, semiconductor state, control calendar |
| Restart qualification | Complete state serialization and deterministic replay |

# Configuration record

Every controlled run should retain:

| Category | Record |
|---|---|
| Backend | Capability/backend identifier and revision |
| Precision | Numeric type/precision |
| Timestep | Value and fixed/adaptive policy |
| Horizon | Start and stop time |
| Integration | Declared method or companion policy |
| Linear solve | Backend, ordering/preconditioner where user-selectable |
| Nonlinear solve | Method, tolerances, maximum iterations, limiting |
| Events | localization, alignment, priority, collision policy |
| Tasks | sample/delay/hold/PWM/protection calendars |
| Histories | delay interpolation and initialization |
| Checkpoints | times, format/schema, compression/checksum |
| Hardware | OS, CPU, threads, optional accelerator |
| Determinism | seed and reproducibility policy |

# Failure categories

## Configuration failure

Examples: missing authorized backend, incompatible versions, missing dependency, inaccessible artifact, or unsupported hardware.

Action: correct the environment. Do not interpret as a model result.

## Invalid input

Examples: wrong units/base, missing model parameter, invalid topology, nonpositive required value, incompatible matrix, event outside horizon, or validity-domain violation.

Action: repair engineering input; do not tune numerical tolerances to hide it.

## Assembly failure

Examples: unresolved node, singular topology, conflicting ideal sources, unsupported element, or dimension mismatch.

Action: inspect topology and model contributions.

## Nonlinear nonconvergence

Examples: poor initial point, discontinuity, ill-scaled residual, invalid constitutive law, too-large timestep, or topology inconsistency.

Action: review model/input first, then initialization/timestep/solver policy. Report any changed policy.

## Unstable or non-passive fit

Examples: right-half-plane poles, negative passivity margin, mode discontinuity, or extrapolation beyond fit range.

Action: repair the identification, weighting, order, sample domain, or passivity enforcement. Do not run an energy-creating fit merely because its local curve appears accurate.

## Event chatter or missed event

Examples: repeated threshold crossing, inconsistent hysteresis, event between steps without localization, or conflicting simultaneous transitions.

Action: inspect event function, hysteresis/dead band, calendar, and collision policy.

## Restart mismatch

Examples: omitted state, incompatible schema, history-buffer mismatch, scheduler phase mismatch, or non-deterministic random/control state.

Action: reject the checkpoint or fix serialization. Do not claim restart support from physical state alone.

# Diagnostics required for review

A solver-backed result should expose, as applicable:

- capability/backend identity and revision;
- status and warning codes;
- timestep count, event count, and rejected/retried work;
- matrix/factorization statistics;
- nonlinear iteration statistics and residuals;
- KCL/nodal residual;
- power/energy-balance residual;
- passivity/stability diagnostics;
- fit error and correction summary;
- exact event/task occurrence records;
- checkpoint/restart comparison;
- runtime and resource metadata.

Do not suppress warnings when exporting CSV, SVG, or reports. The numerical values and diagnostic context belong together.

# Determinism and restart

A deterministic replay contract includes:

- identical input and revisions;
- fixed execution policy and thread/backend assumptions;
- exact task/event calendars;
- preserved random state;
- preserved dynamic, algebraic, delayed-history, topology, control, protection, and reporting state;
- schema/version compatibility;
- declared comparison tolerance or bitwise criterion.

Compare an uninterrupted run with a checkpoint/restart run at all relevant outputs and internal residuals. One matching terminal waveform is not enough when other state can diverge.

# Performance reporting

Performance measurements should identify:

- model/case and size;
- number of nodes, states, devices, events, and output channels;
- timestep/horizon;
- hardware and thread count;
- backend and revision;
- warm-up/compilation treatment;
- wall time, memory, and optional accelerator transfer overhead;
- numerical result equivalence.

Do not compare runtimes across different fidelities or tolerances as though they solved the same problem.

# Public/private boundary

Public documentation may describe:

- scientific equations and contracts;
- input/output semantics;
- solver responsibilities;
- diagnostics and acceptance evidence;
- integration and capability checks;
- public cases and results.

It should not expose private source, credentials, internal repository paths, proprietary implementation details, or licensed benchmark material. The public model and result contract must remain sufficient for independent review of what the software claims.

# Qualification checklist

Before a solver-backed model is described as supported, verify:

- public capability registration is explicit;
- invalid input and missing backend fail clearly;
- linear/nonlinear residuals are bounded;
- conservation/passivity checks are present where applicable;
- events and multirate releases occur deterministically;
- rollback is atomic;
- checkpoint/restart reproduces uninterrupted execution;
- CPU/optional accelerator results agree within the declared contract;
- at least one public case and focused tests exist;
- documentation states validity and unsupported phenomena.
