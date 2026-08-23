# Native User-Defined Components

This AIMORA-authored public example implements three native Julia component types outside the Engine repository, registers their exact package UUID, namespace, semantic type/version, API version, implementation symbol, and SHA-256 content identity explicitly, binds them to callback-free `AIMORAProject.ExtensionDeclaration` records, and executes them through the existing private numerical owners. Project data contains no source text, closure, module path, library path, `eval` input, loading instruction, or private repository metadata.

## Components and equations

`PublicSampledSaturatingLag` is a zero-order-held control with exact task interval `h_task`: `a=1-exp(-h_task/tau)`, `x[k+1]=x[k]+a*(u[k]-x[k])`, and `y[k]=clamp(gain*x[k],y_min,y_max)`. In this case the declared control unit is ampere, `tau=0.5 ms`, the exact period is `100 us`, and the computational delay is `20 us`. Its held output is consumed by the existing nodal `CurrentInjection`; the extension does not own network assembly or the task calendar.

`PublicCubicCurrentBranch` is a passive two-terminal current law with voltage `v=v_p-v_n`, current `i=g*v+k*v^3`, analytic derivative `di/dv=g+3*k*v^2`, terminal currents `[i,-i]`, and terminal Jacobian `[[d,-d],[-d,d]]`. Voltage is in volts, current in amperes, `g` in siemens, and `k` in amperes per volt cubed. Its current and Jacobian enter the accepted nonlinear-network owner.

`PublicSeriesRLCompanion` uses `v=R*i+L*di/dt` and the trapezoidal companion `G=1/(R+2L/h)`, `I_hist=G*(v_prev+(2L/h-R)*i_prev)`, and `i=G*v+I_hist`. Voltage is positive from its source terminal to its load terminal and current is positive in the same direction. A declared `0.1 S` source-terminal shunt provides finite source impedance and damps trapezoidal discontinuity ringing without replacing any extension equation. The private sibling Solver installs the generic public `stamp!`/`update!` adapter; the extension accepts `(v_prev,i_prev)` only after the coupled solution converges.

## Execution and state ownership

The case uses one existing `ReusableDefinition` identity to compose the control and stateful branch declarations, resolves all declarations against a caller-owned registry, and constructs the three runtime values only from the already-loaded public package. Every declaration disposes continuous, algebraic, discrete, delayed, scheduler, random, history, output, and checkpoint state explicitly; absent families carry a reason.

The existing exact sampled-task scheduler executes sample and delayed-release callbacks on integer ticks. A rising surface `phi=t-300 us` is bracketed and localized by the existing hybrid-event owner; its accepted reset changes the sampled input before the simultaneous control task. The existing nonlinear timestep transaction owns trial evaluation, solve, state acceptance, and rollback. A composite checkpoint captures the nonlinear network, public component state, exact task cursors, event cursor, and output state; one probe interval is executed, restored, and continued bit-for-bit against an uninterrupted run.

Each component emits public `ExtensionOutputValue` records and a terminal `ExtensionExecutionResult` with exact identity, representation/fidelity, terminals, complete state inventory, Project and checkpoint hashes, event/task/output cursors, unit/base declarations, diagnostics, warnings or typed failure, and a deterministic SHA-256 signature. The committed waveform, result-contract table, and summary are reproduced exactly by the case qualification command.

## Run

From an owner worktree with the production backend activated, run:

```bash
make run
```

A public clone can load, inspect, register, declare, and test the three component contracts without the private Solver. A production solve without an activated backend returns AIMORA's typed unavailable-backend result.

## Result artifacts

`outputs/waveform.csv` records the source and load voltages, series current, held control output, and nonnegative cubic absorbed power on every accepted timestep. Inspect the delayed control changes at the exact sampled-task boundaries and confirm that the load response remains finite and continuous between accepted event/task transitions.

`outputs/waveform.svg` is the curated visual view of the same accepted voltage, current, and control channels. Compare its event-time and delayed-task transitions with the CSV rather than treating the rendered line widths as additional numerical evidence.

`outputs/result_contract.csv` records each component's exact accepted identity, representation, fidelity, terminal order, event/task/output cursors, Project signature, checkpoint signature, and deterministic result signature. Matching Project signatures show that all three component results belong to the same inert declaration set; distinct checkpoint and result signatures retain component-owned state and output identity.

`outputs/summary.md` records the aggregate deterministic signature, exact event and task counts, maximum KCL residual, passivity minimum, and checkpoint/restart equality. A valid regenerated result must preserve the declared event time, execute the event once, keep cubic absorbed power nonnegative, satisfy the KCL allowance, and reproduce the uninterrupted trajectory bit-for-bit after checkpoint restore.

## Validity and security boundary

This evidence covers API major version 1 on Julia 1.10/current, instantaneous switching-detailed EMT, finite SI inputs, one two-node coupled network, three explicitly registered instances, a `10 us` timestep, a `100 us` task period, one directed event, and 100 accepted steps. The broader qualified boundary is 1-32 nodes, 1-64 instances, 1 us-1 ms timesteps, 10 us-10 ms task periods, at most eight surfaces per instance, and at most 1,000 accepted steps; every wider domain requires separate evidence.

The example is not ATP MODELS or Type-94 compatibility, a PSCAD user component, FMI or Modelica conformance, an unrestricted native-code interface, a stable private-kernel ABI, a manufacturer model, standard conformance, or certification. It does not authorize arbitrary project-file execution or automatic package loading, and it makes no claim about user-supplied physics beyond the declared contracts and evidence.
