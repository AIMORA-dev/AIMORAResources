# Optional DASSL-Class Variable-Step EMT

AIMORA provides an optional DASSL-class variable-step, variable-order implicit DAE mode for a deliberately narrow set of admitted instantaneous-EMT owners. Existing projects and APIs continue to select fixed-step EMT unless the caller explicitly constructs `EMTIntegrationSelection(DASSLClassEMTSettings(...))`. Fixed-step execution remains the reference for switching detail, convergence comparisons, and real-time/HIL workflows.

## Numerical formulation

For differential and algebraic state `x = [y; z]`, the selected mode solves `F(t, x, xdot; p) = 0`. At candidate time `t_n`, derivative weights are the derivatives of the Lagrange basis through the candidate and accepted history, so each differential component uses `xdot_n = sum(w_j x_(n-j))`; algebraic derivative slots remain zero. Newton correction uses the effective Jacobian `F_x + w_0 F_xdot`. Orders one through five and step size are selected only from accepted smooth history. A rejected trial cannot modify physical owners, accepted numerical history, events, tasks, outputs, or checkpoint state.

Each component uses `ewt_i = atol_i + rtol_i max(abs(x_i), abs(x_pred_i))`; correction and residual tests use a weighted root-mean-square norm. Requested output inside one smooth accepted segment uses the accepted interpolation polynomial. The interpolant never crosses a task, root, topology transition, reset, or consistency restart. Exact transition output is labelled `left` or `right`.

## Selection and preparation

```julia
using AIMORA

settings = DASSLClassEMTSettings(
    initial_step_s=2e-6,
    minimum_step_s=1e-10,
    maximum_step_s=2e-4,
    maximum_order=5,
    relative_tolerance=1e-8,
)
selection = EMTIntegrationSelection(settings)
```

`DASSLClassEMTNetworkRequest` declares exact owner identities, node count, interval, initial voltages, SI absolute tolerances and residual scales, requested output times, directed roots, and exact tasks. `dassl_class_emt_readiness(request)` returns a sorted typed disposition for every physical owner before runtime allocation. `prepare_dassl_class_emt(request)` and `execute_dassl_class_emt!(prepared)` use only an explicitly activated backend; without one they return `SolverUnavailableResult` rather than loading a private package or falling back to fixed step.

## Initially admitted owners

The released slice admits canonical finite-conductance ideal sources, current injection, conductance, series R-L, series R-L-C, capacitor, memoryless exponential and cubic current laws with analytic Jacobians, exact time-switch resistance changes without current-extinction history, and one wound-field synchronous-machine electromagnetic/shaft realization with its sampled control owner. Validation-only manufactured residuals are not production physical owners.

Preparation refuses every exact type, fidelity, state, event, delay, topology, or snapshot intersection outside that matrix. Important refused owners include fixed-coefficient or frequency-dependent history elements without a variable-time reconstruction certificate, switch-detailed PWM and semiconductor owners with fixed-step trial state, unsupported transformer/hysteresis realizations, partitioned/local-subcycling execution, arbitrary native extensions, stochastic mutation, and real-time/HIL.

## Public example and outputs

The `emt_dassl_class_variable_step` catalog entry executes four inspectable boundaries:

- A passive Thevenin/series-RLC system publishes requested-grid dense output, KVL and charge residuals, nonnegative stored energy, and exact split/restart state identity.
- A nonlinear cubic-current/capacitor system closes and opens a resistance switch at exact boundaries and publishes both left and right transition states.
- A wound-field synchronous machine executes its electromagnetic flux, shaft, one source event, and two sampled-control releases.
- An unsupported ideal-transformer constraint returns `owner_type_not_admitted` before numerical allocation.

The runner writes deterministic CSV and SVG products for all three admitted trajectories, a result-contract table with state/work/signature data, and a summary with the refusal and unsupported boundary. Set `AIMORA_SOLVER_PATH` explicitly to generate these artifacts; no private path is serialized into them.

## Measured scale and crossover

On Julia 1.12.6/Linux/skylake with one Julia and BLAS thread, the equal-output fixed-step crossover has two deliberately different boundaries. For a constant algebraic Thevenin-source/load problem with 41 requested outputs, direct fixed evaluation required `0.000000742 s`, while DASSL-class execution required `0.000331845 s`; the maximum voltage difference was `6.91e-10 V`, so fixed execution was about 447 times faster. For the stiff passive RLC trajectory at the same 41 requested times, DASSL-class execution required `0.002486814 s`, while the independently implemented fixed BDF reference required `6.334348791 s` and a `3.0517578125e-9 s` step to meet or exceed the DASSL trajectory accuracy over the full output grid. This establishes one measured crossover from algebraic overhead to stiffness-driven adaptive benefit; it does not establish a universal crossover for other models, tolerances, event densities, hardware, or fixed-step implementations.

The canonical scale tier executed 100,000 total states—33,338 differential and 66,662 algebraic—with 200,088 sparse nonzeros, one root, four exact tasks, and seven outputs. Admission required `0.693864860 s`, setup `18.529590169 s`, first execution `31.666119924 s`, warmed execution `32.279843721 s`, and checkpointing `1.289381425 s`; peak resident memory was `2,021,896,192` bytes. It accepted 44 steps across BDF orders one through five with zero rejected steps, localized the root, performed five consistency restarts, and ended with residual WRMS `4.69e-5`, machine-decomposition error `1.50e-7`, and endpoint-voltage errors below `4.4e-15 V`. This scale result has no equal-fidelity fixed-step timing and therefore supports readiness and resource bounds, not a speedup claim.

## Validity and evidence boundary

Native-Linux qualification covers deterministic index-one systems within the state, step, tolerance, output, and boundary ceilings declared by the accepted requirement and each admitted owner. Independent Julia formulations cover passive RLC, wound-field machine, stiff nonlinear and manufactured index-one problems, interpolation, events, conservation/passivity, restart, uncertainty, and refinement. Exact pinned SUNDIALS IDA 7.8.0 and OpenModelica 1.27.0 executions cover only their declared Robertson and nonlinear-root overlaps. External agreement does not establish algorithm identity.

This capability does not claim arbitrary high-index DAE support, every EMT owner, unrestricted stepping through switch detail, exact DASSL/DASPK/IDA/OpenModelica behavior, ATP/PSCAD compatibility, universal speedup, guaranteed convergence, standard conformance, certification, or native private macOS/Windows execution. The accepted fixed-step behavior and default remain unchanged.
