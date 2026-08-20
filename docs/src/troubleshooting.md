# Troubleshooting

Use this guide by failure category. Preserve the original error, revision, command, and input before changing anything. Do not remove warnings or relax tolerances until the underlying cause is understood.

# Installation and repository access

## Submodule checkout fails

Symptoms:

- repository not found;
- permission denied;
- authentication prompt loops;
- submodule directory exists but is empty;
- detached submodule at an unexpected revision.

Checks:

```bash
git submodule status --recursive
git submodule sync --recursive
git submodule update --init --recursive
```

Confirm that the linked GitHub identity can read every required private repository. A visible gitlink in the workspace does not grant access to the child repository.

Do not replace production submodule URLs or revisions silently. Record any deliberate fork/remap in the workspace change.

## Julia cannot find `AIMORA`

Confirm that you are using the intended project and that the engine checkout is on `LOAD_PATH` or registered as a dependency.

```bash
julia --project=. -e 'using Pkg; Pkg.status()'
julia --project=. -e 'using AIMORA; println(pathof(AIMORA))'
```

For documentation:

```bash
export AIMORA_DOCS_ENGINE_PATH=/absolute/path/to/AIMORA.jl
make -C docs build
```

## Package instantiate fails

Run:

```bash
julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

Review the exact `Project.toml` and `Manifest.toml`; do not delete the manifest merely to hide an incompatibility. Verify Julia compatibility and repository/artifact access.

# Solver capability

## `solver_available()` is false

This means no authorized production backend registered successfully.

```bash
julia --project=. -e 'using AIMORA; println(AIMORA.solver_status())'
```

Check:

- authorized solver checkout is present at the pinned revision;
- environment includes its package/dependencies;
- compatible engine and solver revisions are used;
- registration code runs before the case requests the backend;
- no private dependency or artifact is inaccessible.

A solver-required case should be marked **BLOCKED**, not falsely passed through a historical or reduced path.

## Solver version incompatible

Return to the workspace-pinned revisions. Do not mix arbitrary engine and solver branch tips. Capture both SHAs and the compatibility error in the issue/report.

# Input and parser failures

## Unknown card or section

Check spelling, case, fixed-field columns, active section, and study context. Compare with a registered example and the generated [Deck and Card Declaration Index](generated/deck-card-index.md).

Unknown cards must not be ignored. Use a supported card family or implement/document/test the new one.

## Continuation record is orphaned

A continuation must immediately or deterministically attach to a compatible parent. Check parent marker, ordering, expected continuation count, blank/comment rows, and fixed columns.

## Numeric conversion fails

Look for:

- comma decimal separators;
- stray unit text in a numeric field;
- fixed-field overflow/truncation;
- `NaN`/`Inf`;
- unsupported exponent notation;
- tabs shifting columns.

After syntax is fixed, semantic validation may still reject the value physically.

## Unresolved reference

Check that node/device/control/winding/conductor identifiers are unique and defined before semantic resolution. Look for normalization differences in whitespace/case.

## Matrix dimension mismatch

Verify phase/conductor/terminal ordering, matrix row count, continuation count, and whether the card expects full, triangular, sequence, modal, or reduced data.

# Validity-domain and unit failures

## Fidelity mismatch

The requested fidelity is not supported by the model contract. Select an appropriate model or provide the data needed for a supported higher-fidelity model. Do not override the check without documenting why the model contract is wrong.

## Quantity outside bounds

Confirm unit/base conversion first. Then determine whether the case is physically outside the model domain or the bound is incorrect. Extrapolation must be explicit and usually produces a warning or rejection.

## Per-unit result appears wrong by a constant factor

Check voltage/current/power bases, phase versus three-phase base, RMS versus peak, and turns/side conversion. Keep base values with every per-unit quantity.

## Sign is reversed

Check terminal orientation, passive sign convention, source direction, phase order, mechanical torque direction, and absorbed/delivered power convention. Do not multiply by −1 in post-processing without correcting/documenting the contract.

# Nodal and topology failures

## Singular matrix

Common causes:

- floating island without a reference;
- ideal voltage-source loop;
- ideal current-source cutset;
- duplicate ideal constraints;
- open topology that isolates dynamic state;
- missing shunt/reference path;
- zero/invalid parameter creating an unintended ideal branch;
- event produced an unsupported topology.

Inspect topology before changing numerical settings.

## Ill-conditioned solve

Check unit scaling, extreme conductance ratios, nearly dependent constraints, invalid fit/state-space scaling, and nonphysical parameters. Report condition/scaling diagnostics where available.

## KCL residual spikes at events

A localized discontinuity may cause a bounded transient residual, but persistent or large spikes can indicate event ordering, stale factorization, history-source update, or topology rollback errors. Compare requested/executed event times and inspect the first accepted post-event state.

# Nonlinear convergence

## Nonlinear iterations do not converge

Check in this order:

1. constitutive curve and units;
2. initial operating point;
3. discontinuity/event timing;
4. Jacobian/derivative validity;
5. residual scaling;
6. topology consistency;
7. timestep;
8. damping/limiting policy;
9. tolerance and iteration limit.

Do not mark the final iterate successful. Preserve residual/iteration logs.

## Arrester or exponential model overflows

Check voltage/current units, coefficient basis, exponent scaling, validity interval, and limiting policy. An overflow can indicate input far outside the fitted characteristic.

## Chattering around a threshold

Add or verify physical/numerical hysteresis, dead band, minimum event separation, exact event localization, and state-dependent direction. Report chatter prevention; do not silently drop transitions.

# Lines, cables, and fitting

## Arrival time is wrong

Check line length units, propagation velocity/delay, phase/modal transformation, initial histories, and event origin. Distinguish one-way and round-trip time.

## Frequency scan is discontinuous

Check sample ordering, geometry/material changes, modal sorting/sign, matrix conditioning, branch cuts, and numerical precision. Plot raw phase matrices as well as derived modal/sequence values.

## Rational fit has low error but unstable runtime

Inspect poles and passivity. A pointwise fit can be unstable or non-passive. Enforce stability/passivity using a documented method and compare corrected versus original response.

## Passivity correction changes the fit too much

Review frequency grid, scaling, weighting, order, noisy/inconsistent samples, modal transformation, and chosen correction objective. Report the tradeoff rather than hiding it.

## Cable geometry rejected

Check strictly nested radii, positive thickness, conductor/layer ownership, material values, phase placement, and units. An off-center or nested model must satisfy its specific geometric constraints.

# Transformers

## Short-circuit tests are not reproduced

Check winding/test order, bases, temperature, tap, vector group, percentage versus per-unit conversion, test pair definition, and allocation assumptions for multiwinding data.

## Inrush waveform is implausible

Check switching point, source impedance, initial/remanent flux, saturation/hysteresis curve, core topology, winding connection, timestep, and event localization. Parameter conversion alone is not an inrush model.

## Wideband terminal fit is non-passive

Check port order, reference convention, measured/synthetic data consistency, frequency range, order, and passivity correction. Do not run a non-passive terminal model as accepted evidence.

# Machines and shafts

## Machine starts from the wrong operating point

Check electrical/mechanical bases, phase/dq convention, rotor angle reference, speed units, slip, mechanical torque/power sign, and initialization method.

## Torque and power have inconsistent signs

Check passive sign convention, generator versus motor mode, electrical/mechanical direction, pole-pair conversion, and whether speed is electrical or mechanical.

## Torsional oscillation frequency is wrong

Check inertia base and units, stiffness/damping units, mass order, shaft topology, and electrical torque coupling point. Compare calculated natural modes with input/model expectations.

## Control release drifts

Use exact rational scheduling. Check sample period representation, start phase, computational delay, hold, and checkpoint scheduler state. Floating-point accumulation should not determine release times.

# Converters

## DC-link energy balance is poor

Check DC/AC power signs, capacitor energy definition, switching/device losses represented, source resistance, control sampling, gate/conduction state, and output integration.

## Gate command and conduction state differ

This can be physical when antiparallel paths, dead time, blocking, or commutation are represented. Review both signals and device orientation; do not assume gate equals current path.

## Switching waveform is noisy or aliased

Check electrical timestep relative to switching period, event alignment, output decimation/filtering, and plotting sample rate. A coarse output series can alias a correctly solved internal waveform.

## Average-value and switching model disagree

Compare only quantities within the overlapping bandwidth and assumptions. Average-value models omit switching ripple, dead time, and device commutation by design.

# Results and files

## Expected output missing

Check result status/warnings, output request, target identity, output directory permissions, case working directory, and whether the case was blocked before execution.

## CSV columns are ambiguous

Use stable names plus a schema/sidecar for units, targets, phase order, bases, and signs. Regenerate the report; do not guess columns downstream.

## Plot looks correct but checks fail

Trust quantitative diagnostics. Inspect KCL, energy, passivity, convergence, event, and comparison gates. A visually plausible curve is not acceptance evidence.

# Checkpoint and restart

## Checkpoint rejected

Check engine/model/solver schema versions, topology, timestep/scheduler policy, state dimensions, and checksum. Recreate the checkpoint from a compatible revision.

## Restart trajectory diverges

Likely missing or mismatched:

- dynamic/algebraic state;
- delay/history buffers;
- topology/switch state;
- nonlinear branch/hysteresis state;
- control/protection/scheduler state;
- random state;
- pending event queue;
- output/report accumulator.

Compare immediately after restart to locate the first divergence.

# Documentation build

## Documentation cannot locate engine

Place `AIMORA.jl` beside `AIMORAResources` or set:

```bash
export AIMORA_DOCS_ENGINE_PATH=/absolute/path/to/AIMORA.jl
```

Then run:

```bash
make -C docs clean
make -C docs generate
make -C docs check
make -C docs build
```

## Generated reference page is missing

Run the generator. It scans public model/parser source, the typed study catalog, and the canonical case catalog:

```bash
make -C docs generate
```

A generation failure normally identifies an unavailable engine path, package-load failure, or malformed case catalog.

## Documentation check reports a broken link

Use a local relative link for another documentation page and include the `.md` extension in source. Confirm the page is in `docs/make.jl` navigation if it is user-facing.

# Minimal issue report

Include:

```text
case/study/model ID
exact reproduction command
workspace, engine, solver, resources SHAs
Julia/OS/hardware
input or minimal reproducer
status and warnings
full error/stack trace
expected versus actual behavior
first failing timestep/event if known
residual/convergence evidence
whether uninterrupted and restart runs differ
```

Remove secrets and proprietary input before sharing. Do not remove the metadata needed to reproduce the failure.
