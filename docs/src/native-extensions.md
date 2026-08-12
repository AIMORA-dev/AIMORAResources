# Native User-Defined Components

AIMORA's native extension boundary lets a Julia package contribute bounded electrical devices, nonlinear current laws, controls, sources, event surfaces, sampled tasks, typed outputs, checkpoints, and reusable composition without forking the Engine or depending on private solver internals. The public Engine owns the contract and registry, `AIMORAProject` owns callback-free declarations, and the private sibling Solver owns global assembly, nonlinear iteration, timestep transactions, event ordering, task scheduling, and acceptance.

## Identity, loading, and registry

Every implementation declares an `ExtensionIdentity` containing its package UUID, lowercase namespace, semantic type and version, Julia implementation symbol, public API version, and SHA-256 content identity. The application loads a normal Julia package by its own explicit policy and then registers an already-loaded concrete type in a caller-owned `ExtensionRegistry`.

```julia
using AIMORA
using AIMORACases

registry = AIMORACases.native_extension_registry()
identity = AIMORA.NativeExtensions.extension_identity(
    AIMORACases.PublicCubicCurrentBranch,
)
registration = AIMORA.NativeExtensions.resolve_extension(registry, identity)
```

Registration validates exact package identity, contract identity, representation, fidelity, complete state inventory, services, and required methods. An unknown, mismatched, or duplicate identity returns a typed `ExtensionFailure`; the registry never scans packages, follows a module path, or loads an implementation automatically.

## Inert Project declaration

`AIMORAProject.ExtensionDeclaration` stores only immutable semantic data: object identity, `RegisteredFunctionIdentity`, API version, representation, fidelity, typed terminal references, inert typed parameters, all nine state-family dispositions, services, upstream and output contracts, an optional `ReusableDefinition` reference, and provenance. It cannot store a closure, Julia source text, module or native-library path, `eval` input, credentials, or a loading instruction.

Resolution compares that inert record with one explicit registry entry. Project terminal count, services, representation, fidelity, package UUID, namespace, type/version, API version, implementation symbol, and content hash must match before construction. Parameters carry their source, units, base/orientation, transformation, uncertainty/default policy, validity, and physical, scaling, or numerical role; callbacks never infer RMS versus peak, phase orientation, sign, or a per-unit base.

## Public equations and signs

The redistributable case in `AIMORACases.jl/examples/emt/user_defined_components` contains three source files owned by the external Cases package.

The sampled saturating lag uses a zero-order-held input and exact task interval (h_t):

```math
a=1-\exp(-h_t/\tau),\qquad x_{k+1}=x_k+a(u_k-x_k),\qquad y_k=\operatorname{clamp}(g x_{k+1},y_{\min},y_{\max}).
```

Its state, held input/output, delayed pending value and release tick, next sample tick, sample/write counts, outputs, and checkpoint digest are explicit. The held output can implement the typed `source` service and is consumed by the existing nodal `CurrentInjection`; it does not own assembly or a second source subsystem.

The passive cubic branch orients voltage and current from its positive to negative terminal:

```math
v=v_p-v_n,\qquad i=g v+k v^3,\qquad \frac{\mathrm di}{\mathrm dv}=g+3k v^2.
```

It stamps terminal currents ([i,-i]) and the analytic Jacobian ([d,-d;-d,d]). Voltage is volts, current amperes, (g) siemens, and (k) amperes per volt cubed. With (g\ge 0) and (k\ge 0), absorbed power (vi=g v^2+k v^4) is nonnegative.

The stateful series R-L component orients voltage and current from its positive to negative terminal and uses

```math
v=Ri+L\frac{\mathrm di}{\mathrm dt},\qquad G=\frac{1}{R+2L/h},\qquad I_{\mathrm{hist}}=G\left(v_{n-1}+(2L/h-R)i_{n-1}\right),\qquad i_n=Gv_n+I_{\mathrm{hist}}.
```

Resistance is ohms, inductance henries, time seconds, and stored energy (Li^2/2) joules. The extension supplies the companion and accepts previous voltage/current only after the existing global solve converges. Trial evaluation does not mutate accepted history.

## Runtime lifecycle

The accepted order is: resolve an inert declaration against the explicit registry; verify identity, compatibility, services, state, terminals, parameters, units/bases, validity, and methods; construct an isolated candidate; initialize it; begin the existing timestep transaction; evaluate pure trial callbacks; let the network, event, and task owners solve and order work; restore on failure; accept component state once; publish outputs once; then advance checkpoints and deterministic signatures once.

An extension never owns global unknown ordering, network assembly, factorization, nonlinear iteration, line search, timestep acceptance, event iteration, or the sampled calendar. The generic private R-L adapter delegates to the existing `Branches.stamp!` and `Branches.update!`; the cubic branch delegates to `NonlinearNodal`; exact sampled work delegates to `ExactSampledTaskScheduler`; directed zeros delegate to `HybridEventSurface` and `localize_hybrid_event!`; and rollback delegates to the accepted timestep transaction and checkpoint owners.

## Events, tasks, checkpoints, and outputs

`DirectedExtensionEvent` declares quantity, threshold, direction, tolerance, priority, occurrence bound, and accepted cursor. The public case brackets the rising surface (\phi=t-300\,\mu\mathrm{s}), localizes it through the hybrid-event owner, executes one reset, and lets a task due at the same time observe the reset in the declared event-before-task order.

Sampled tasks use exact integer ticks and a read, compute, delay, write, hold order. The public control samples every (100\,\mu\mathrm{s}), releases after (20\,\mu\mathrm{s}), writes once per sample, and checkpoints both pending values and task cursors. Restore captures the nonlinear network, component states, task states and occurrence count, event cursor/reset state, and outputs; continuation must match an uninterrupted run bit-for-bit without a duplicate event or task.

`ExtensionOutputValue` carries channel name, finite numeric value, unit, nonnegative time, validity, and exact extension identity. `ExtensionExecutionResult` is the terminal accepted-or-failed contract: it records identity, representation/fidelity, terminals, complete state inventory, Project and checkpoint hashes, event/task/output cursors, diagnostics, units/bases, warnings or typed failure, and a deterministic SHA-256 signature. A failed execution has a typed failure and publishes no accepted mutation.

## Reusable composition and migration

An extension declaration may reference an existing `ReusableDefinition`; the public case binds its control and stateful electrical component to one definition identity instead of creating another hierarchy owner. Expansion remains deterministic and preserves the exact component identities and terminal bindings.

Version loading is exact by default. A registered migration can advance one semantic version at a time only within the same package UUID, namespace, and type. It receives inert data, must not mutate its source, and must replay deterministically. Missing steps, backward or cross-type movement, content mismatch, source mutation, nondeterminism, or unsupported major-version policy return typed failures without loading an implementation package.

## Example and performance boundary

Run the coupled public example from an `AIMORACases` checkout with the public Engine available on its declared local path:

```bash
julia --project=. examples/emt/user_defined_components/run.jl
```

The case proves explicit registration and Project binding, reusable composition, real R-L stamp/state acceptance, real nonlinear residual/Jacobian consumption, a typed held source with a declared finite source shunt, exact task delay/hold, localized directed event/reset, typed outputs, deterministic artifacts, and checkpoint/restart. Independent qualification separately compares the lag, cubic, R-L, and event-root equations; checks finite-difference Jacobians, passivity, conservation, refinement, mutations, and invalid contracts; and measures P0 (one instance of each) and P1 (64 mixed instances on 32 nodes for 1,000 accepted steps) at equal equations, timestep, tolerances, event/task order, checkpoints, outputs, and accuracy.

Warmed extension overhead is accepted only when it is no more than twice the equivalent built-in path and adds no more than 256 bytes per instance-step beyond retained payload; P0 setup must remain below 2 MiB and P1 warmed execution below 32 MiB beyond equivalent retained payload. Compilation/setup are reported separately and no timing target terminates a healthy test.

## Validity, failures, and exclusions

The qualified domain is public API major version 1 on Julia 1.10/current; instantaneous switching-detailed EMT; 1-32 nodes; 1-64 registered instances; finite SI parameters; two-terminal electrical examples; 1 microsecond-1 millisecond timesteps; exact 10 microsecond-10 millisecond task periods; at most eight event surfaces per instance; and at most 1,000 accepted steps. Every extension may narrow this domain. A wider topology, state size, rate, representation, fidelity, or platform version is unsupported until separately qualified.

Typed failures cover unknown or mismatched identity, unsupported representation/fidelity/service, missing method/parameter/state family, invalid units/base/orientation or terminals, nonfinite residual/Jacobian/output, analytic-Jacobian mismatch, singular/nonconvergent solve, trial mutation, non-forward or repeated event, missed task, incompatible checkpoint, stale Project/result signature, and unsupported migration.

This native API does not claim ATP MODELS or Type-94 compatibility, PSCAD user-component compatibility, FMI or Modelica conformance, unrestricted native-library execution, ABI stability for private kernels, manufacturer behavior, standard conformance, or certification of user-supplied physics. No proprietary model, external simulator result, private solver source, restricted evidence, or automatic code-loading instruction is included in the public release.
