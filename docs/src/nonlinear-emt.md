# Nonlinear and Discontinuity-Safe EMT

AIMORA's licensed instantaneous-EMT engine can couple public device-owned current laws and analytic Jacobians to linear companion networks and ideal voltage constraints. The public model boundary owns terminals, constitutive parameters, physical scaling, accepted device state, and typed results; the separately distributed numerical component owns scaled KCL/MNA assembly, safeguarded Newton iteration, dense/sparse factorization, conditioning, refinement, rollback, and discontinuity-safe history updates.

## Physical equations and signs

For node voltage vector (v), ideal-constraint current vector (lambda), linear companion admittance (Y), known source/history current (j), device incidence (A_d), device current (i_d), ideal-constraint incidence (B), and constraint value (e), the solved physical residual is

```math
R(v,\lambda)=\begin{bmatrix}Yv-j+B^\mathsf{T}\lambda+\sum_d A_d^\mathsf{T}i_d(A_dv)\\Bv-e\end{bmatrix}.
```

A device terminal current is positive leaving its declared terminal, a positive source injection enters the nodal right-hand side, ideal-constraint current follows the declared coefficient orientation, KCL residuals are amperes, and ideal-constraint residuals are volts. The analytic modified-nodal Jacobian is

```math
J=\begin{bmatrix}Y+\sum_d A_d^\mathsf{T}(\partial i_d/\partial v_d)A_d&B^\mathsf{T}\\B&0\end{bmatrix}.
```

Physical voltage and current scales form diagonal matrices (D_x) and (D_r), giving the dimensionless system (hat R=D_r^{-1}R(D_xhat x)) and (hat J=D_r^{-1}JD_x). Scaling changes neither a physical sign nor an equation; every scale must be finite, positive, and representative of the solved network rather than an arbitrary numerical escape.

## Constructing a network

The example below uses the reusable cubic current branch and an ideal 1 V terminal constraint. A fitted ZnO characteristic can enter the same contract through `AIMORA.Nonlinear.FittedZincOxideCurrentBranch`, which reuses the existing positive continuous ZnO fit owner rather than introducing a second arrester model.

```julia
using AIMORA
using AIMORA.Branches
using AIMORA.Nodal
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal

linear = NodalSystem(2, [
    ConductanceBranch(1, 0, 1.0),
    ConductanceBranch(2, 0, 1.0),
    CurrentInjection(1, _time_s -> 2.7),
    CurrentInjection(2, _time_s -> 0.3),
])

system = NonlinearNodalSystem(
    linear,
    [CubicCurrentBranch(
        1,
        2;
        linear_conductance_s=0.2,
        cubic_coefficient_a_per_v3=0.1,
    )];
    ideal_constraints=[IdealVoltageConstraint((1, 2), (1.0, -1.0), 1.0)],
    scales=NonlinearNetworkScales([2.0, 1.0], [3.0, 1.0], [1.0], [1.0]),
)

result = solve_nonlinear_algebraic_state!(system, 0.0, 10e-6)
result.accepted || throw(result.failure)
```

Custom devices subtype `AbstractNonlinearCurrentDevice`, declare `PhysicalConstitutiveCurrent`, `ComplementarityCurrent`, `SemismoothCurrent`, or `BoundedRegularizedCurrent` through `nonlinear_device_formulation`, return a `NonlinearParameterProvenance` from `nonlinear_device_provenance`, return ordered physical terminal nodes from `nonlinear_terminal_nodes`, and fill both terminal currents and the analytic terminal-voltage Jacobian in `nonlinear_current_jacobian!`. Provenance records the parameter source, units, transformation, uncertainty, validity domain, and whether a value is physical data, a scaling basis, or numerical policy; omitted measurement uncertainty remains explicitly caller-owned instead of being silently treated as zero. This released slice admits only physical constitutive-current devices with physical-model provenance; complementarity, semismooth, bounded-regularized, missing-provenance, and misclassified-provenance declarations are explicitly refused until their own equations and evidence are qualified. Trial evaluation must not mutate accepted state, and stateful devices accept state only through `accept_nonlinear_device_state!` after the coupled solution converges.

`IdealVoltageConstraint((positive_node, negative_node), (1.0, -1.0), value_v)` owns the MNA equation for an ideal voltage source. Setting `value_v` to zero is the admitted closed ideal-switch constraint because it enforces equal terminal voltage while the constraint-current unknown carries the branch current; the open state is represented by removing that constraint through the authoritative topology/event owner, not by a hidden leakage or large resistance.

## Executing an exact fixed-step study

`NonlinearEMTStudySchedule` owns the exact fixed-step calendar and accepts only typed discontinuities already localized to that calendar. `evaluate_nonlinear_emt_network!` advances each interval once, records the initial and accepted voltage/ideal-constraint-current states, preserves event order through the step index, and returns one diagnostic record per accepted interval.

An already accepted `EMTHybridEventOccurrence` can be adapted with `NonlinearEMTDiscontinuity(occurrence)`, and already executed `EMTSampledTaskOccurrence` values can be supplied through `accepted_tasks`. The schedule preserves simultaneous event priority/name order and sampled-task priority/name order exactly as received, never replays their transitions or creates scheduler indices, and refuses a critical-damping chatter decision at any accepted event or task boundary.

```julia
using AIMORA.EMTStudy

schedule = NonlinearEMTStudySchedule(
    10e-6,
    1e-3;
    discontinuities=[NonlinearEMTDiscontinuity(0.5e-3, :topology_change)],
)
trace = evaluate_nonlinear_emt_network!(system, schedule)
size(trace.voltage_v) == (2, 101)
length(trace.diagnostics) == 100
```

The schedule rejects repeated, out-of-horizon, off-grid, and untyped discontinuities before advancing the network. A failed interval throws its typed `NonlinearSolveFailure` after the timestep transaction restores the last accepted state; the study never writes a duplicate accepted sample.

## Solver behavior and diagnostics

Each iteration assembles the true physical residual and Jacobian, applies declared row and variable scales, diagnoses numerical rank and condition, solves a Newton correction, optionally refines the correction with an extended-precision residual, and accepts only an Armijo sufficient-decrease trial. Systems below `sparse_dimension_threshold` use exact singular values for two-norm condition and rank diagnostics. Larger systems factor the topology-derived sparse pattern once per current Jacobian, use the same factor in a deterministic `maximum_condition_estimation_steps`-bounded Hager/Higham one-norm estimator and Newton solve, and diagnose suspicious or failed factors from scaled U pivots. A regularized normal-equation fallback can seek a descent direction, but it cannot turn an island, incompatible ideal constraints, invalid Jacobian, or structurally singular topology into convergence.

Small systems use dense LU; systems at or above `sparse_dimension_threshold` use a topology-derived sparse structural pattern. Unchanged topology reuses the sparse symbolic factorization while each current Jacobian receives one numeric refactorization shared by conditioning and Newton correction. The current P2 slice still assembles and scales the physical Jacobian in dense storage before copying its structural entries into sparse factor storage, so it qualifies sparse factorization and symbolic reuse but does not claim direct sparse stamping or assembly. A topology signature change invalidates the cache, and checkpoints retain the accepted topology signature without serializing private factor objects.

`NonlinearSolveDiagnostics` reports the per-substep, per-iteration physical KCL, constraint, and tolerance-normalized residual history; final residual maxima; instantaneous nonlinear-device absorbed power, ideal-constraint absorbed power, and algebraic power-balance residual; maximum scaled step; condition estimate; numerical rank and dimension; line-search and fallback counts; symbolic and numeric factorization counts; factor reuse; iterative refinement; structural nonzeros; selected linear solver; topology signature; companion method; accepted substeps; chatter classification; and discontinuity reason. The power values describe the final evaluated candidate and are not an integrated stored-energy model; a rejected result does not imply that candidate was accepted. A rejected result carries `NonlinearSolveFailure`, returns the restored accepted voltages and constraint currents, restores the last accepted network, device, companion, topology-signature, and buffer state, and invalidates any factor cache touched by the rejected topology without exposing a private memory address.

## Discontinuities and chatter

A declared localized event or topology change may select two backward-Euler half steps for one interval. The treatment is admitted only when every history-bearing network element declares a physical backward-Euler companion; the current slice supports scalar series R-L, series RLC, and capacitor histories plus memoryless sources and switches, and refuses undeclared line, transformer, TACS, semiconductor, or user-element histories before mutation. Numerical chatter may select the same critical-damping treatment only after three successive accepted increments alternate in sign, remain above the physical floor, stay within the declared adjacent-amplitude ratio band, and retain unchanged topology, task calendar, and control mode.

`classify_numerical_chatter` explicitly vetoes automatic numerical damping for a localized event, PWM transition, controller transition, topology or task change, and a resolved physical oscillation or energy-supported physical mode. Calling `advance_nonlinear_step!` with `:two_backward_euler_half_steps` therefore requires `:localized_event`, `:topology_change`, or a qualified numerical-chatter decision; a bare request is rejected.

```julia
observation = NonlinearChatterObservation(
    (0.10, -0.09, 0.095),
    1.0;
    topology_unchanged=true,
    task_calendar_unchanged=true,
    control_mode_unchanged=true,
)
decision = classify_numerical_chatter(observation)
step_result = advance_nonlinear_step!(system, 20e-6, 10e-6; chatter_decision=decision)
```

## Checkpoint and restart

`nonlinear_nodal_checkpoint` captures the accepted linear companion, nonlinear-device, ideal-constraint-current, topology, and solve-count state while excluding trial workspace and factor objects. `restore_nonlinear_nodal_checkpoint!` restores that accepted graph in place, preserves the public voltage-buffer identity, invalidates private factor caches, rejects an unknown checkpoint schema explicitly, and rejects a mismatched topology with the typed `:invalid_topology_signature` failure.

## Troubleshooting

- `:structural_rank_deficiency` indicates an island, a missing reference, or dependent/incompatible ideal constraints; repair topology instead of adding hidden conductance.
- `:ill_conditioned_network` indicates that the scaled Jacobian exceeds the declared condition domain; inspect physical bases, parameters, and constraint formulation before widening a numerical limit.
- `:line_search_exhaustion` commonly indicates an invalid analytic Jacobian, a nonphysical constitutive branch, or a starting point outside the admitted domain; compare the analytic derivative with an independent finite difference.
- `:iteration_exhaustion` means the physical residual did not close within the declared iteration count; do not accept the last trial voltage as a solution.
- `:nonfinite_device_current` or `:nonfinite_device_jacobian` identifies the device boundary that produced invalid physics or derivatives; the accepted state remains unchanged.

## Validity and exclusions

The redistributable `AIMORACases.jl/examples/emt/nonlinear_network_discontinuity` case covers a synthetic two-node RLC network, an exact eight-node manufactured topology change, a fitted ZnO branch, ideal constraints, exact localized edges, chatter veto, 20/10/5 µs refinement, energy/passivity checks, and deterministic restart. Performance qualification separately covers P0 systems through 8 nodes, P1 systems through 32 nodes, and sparse P2 systems at 100 and 500 nodes with at least 20 nonlinear devices and declared voltage/current scales; it records script loading, object setup, the first solve including JIT work, a warmed solve, report construction, output-sink emission, and total validation time separately under single-threaded deterministic reduction order. Warmed-solve allocation ceilings are 100 kB for P0, 250 kB for P1, 250 kB for the 100-node sparse P2 solve, 1 MB for its dense reference, and 1 MB for the 500-node sparse P2 solve; the equal-accuracy 100-node sparse/dense crossover ratio must not exceed 1.5.

This capability does not claim adaptive global stepping, arbitrary complementarity families, proprietary ATP or PSCAD behavior, manufacturer arrester accuracy, a measured network, insulation-coordination validity, standard conformance, or certification. Every additional device law, topology, scale range, condition range, event rate, and external comparison requires its own bounded evidence.
