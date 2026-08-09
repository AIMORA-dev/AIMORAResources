#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.Branches
using AIMORA.EMTStudy
using AIMORA.Nodal
using AIMORA.Nonlinear
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal
using AIMORA.Switches
using .ExampleSupport

const SOURCE_VOLTAGE_V = 400.0
const EVENT_TIME_S = 8.0e-4
const FINAL_TIME_S = 2.0e-3
const SERIES_RESISTANCE_OHM = 5.0
const SERIES_INDUCTANCE_H = 10.0e-3
const SERIES_CAPACITANCE_F = 20.0e-6
const LOAD_CONDUCTANCE_S = 0.01
const SWITCHED_CURRENT_A = 0.25
const MANUFACTURED_NODE_COUNT = 8
const MANUFACTURED_EVENT_TIME_S = 5.0e-4
const MANUFACTURED_FINAL_TIME_S = 1.0e-3
const MANUFACTURED_SWITCH_CONDUCTANCE_S = 0.2
const MANUFACTURED_EVENT_JUMP_V = 0.05
const MANUFACTURED_POST_EVENT_RAMP_V_PER_S = 50.0

function fitted_arrester()
    fit = zinc_oxide_piecewise_fit(
        [1.0e-6, 8.0e-6, 64.0e-6, 512.0e-6],
        [100.0, 200.0, 400.0, 800.0];
        reference_voltage_v=100.0,
        segment_count=1,
        relative_error_tolerance=1.0e-10,
    )
    return FittedZincOxideCurrentBranch(2, 0, fit), fit
end

function nonlinear_network()
    arrester, fit = fitted_arrester()
    branch = SeriesRLCBranch(
        1,
        2,
        SERIES_RESISTANCE_OHM,
        SERIES_INDUCTANCE_H,
        SERIES_CAPACITANCE_F,
    )
    switched_source = CurrentInjection(
        2,
        time_s -> time_s >= EVENT_TIME_S ? SWITCHED_CURRENT_A : 0.0,
    )
    linear_system = NodalSystem(
        2,
        [
            branch,
            ConductanceBranch(2, 0, LOAD_CONDUCTANCE_S),
            switched_source,
        ],
    )
    system = NonlinearNodalSystem(
        linear_system,
        [arrester];
        ideal_constraints=[IdealVoltageConstraint((1,), (1.0,), SOURCE_VOLTAGE_V)],
        scales=NonlinearNetworkScales(
            [SOURCE_VOLTAGE_V, SOURCE_VOLTAGE_V],
            [10.0, 10.0],
            [SOURCE_VOLTAGE_V],
            [10.0],
        ),
    )
    return system, branch, fit
end

function physical_chatter_decision(
    increments::NTuple{3,Float64};
    localized_event_present::Bool=false,
)
    observation = NonlinearChatterObservation(
        increments,
        SOURCE_VOLTAGE_V;
        topology_unchanged=true,
        task_calendar_unchanged=true,
        control_mode_unchanged=true,
        localized_event_present,
        resolved_physical_oscillation=true,
        residual_or_energy_supports_physical_mode=true,
    )
    return classify_numerical_chatter(observation)
end

function network_run(step_s::Float64; restart_step::Union{Nothing,Int}=nothing)
    system, branch, fit = nonlinear_network()
    step_count = round(Int, FINAL_TIME_S / step_s)
    event_step = round(Int, EVENT_TIME_S / step_s)
    time_s = collect(0:step_count) .* step_s
    voltage_v = zeros(Float64, step_count + 1)
    constraint_current_a = zeros(Float64, step_count + 1)
    branch_current_a = zeros(Float64, step_count + 1)
    nonlinear_device_power_w = zeros(Float64, step_count + 1)
    stored_energy_j = zeros(Float64, step_count + 1)
    energy_defect_j = zeros(Float64, step_count + 1)
    maximum_kcl_residual_a = 0.0
    maximum_constraint_residual_v = 0.0
    minimum_arrester_power_w = Inf
    maximum_nonlinear_power_diagnostic_error_w = 0.0
    previous_net_power_w = 0.0
    integrated_net_energy_j = 0.0
    localized_discontinuity_count = 0
    localized_event_chatter_veto_count = 0
    physical_chatter_veto_count = 0
    numeric_factorization_count = 0
    iterative_refinement_count = 0
    symbolic_factorization_count = 0
    factor_reuse_count = 0
    increment_history = Float64[]
    checkpoint = nothing
    checkpoint_increments = Float64[]
    checkpoint_voltage_identity = UInt(0)
    probe_voltage_v = NaN

    for step in 1:step_count
        at_discontinuity = step == 1 || step == event_step
        chatter_decision = nothing
        if length(increment_history) >= 3
            chatter_decision = physical_chatter_decision((
                increment_history[end - 2],
                increment_history[end - 1],
                increment_history[end],
            ); localized_event_present=at_discontinuity)
            chatter_decision.classification == :localized_event_veto &&
                (localized_event_chatter_veto_count += 1)
            chatter_decision.classification == :physical_oscillation_veto &&
                (physical_chatter_veto_count += 1)
        end
        result = advance_nonlinear_step!(
            system,
            time_s[step + 1],
            step_s;
            discontinuity_treatment=at_discontinuity ?
                :two_backward_euler_half_steps : :none,
            discontinuity_reason=at_discontinuity ? :localized_event : :none,
            chatter_decision,
        )
        result.accepted || error(
            "nonlinear example solve failed at step $step: $(result.failure)",
        )
        at_discontinuity && (localized_discontinuity_count += 1)
        voltage_v[step + 1] = result.voltage_v[2]
        constraint_current_a[step + 1] = only(result.constraint_current_a)
        branch_current_a[step + 1] = branch.i_last
        stored_energy_j[step + 1] =
            0.5 * SERIES_INDUCTANCE_H * branch.i_last^2 +
            0.5 * SERIES_CAPACITANCE_F * branch.capacitor_voltage_prev^2
        arrester_evaluation = zinc_oxide_fitted_current_and_derivative(
            fit,
            voltage_v[step + 1],
        )
        arrester_power_w = voltage_v[step + 1] * arrester_evaluation.current_a
        nonlinear_device_power_w[step + 1] =
            result.diagnostics.power.nonlinear_device_absorbed_power_w
        maximum_nonlinear_power_diagnostic_error_w = max(
            maximum_nonlinear_power_diagnostic_error_w,
            abs(nonlinear_device_power_w[step + 1] - arrester_power_w),
        )
        minimum_arrester_power_w = min(minimum_arrester_power_w, arrester_power_w)
        switched_current_a = time_s[step + 1] >= EVENT_TIME_S ?
            SWITCHED_CURRENT_A : 0.0
        delivered_power_w =
            -SOURCE_VOLTAGE_V * only(result.constraint_current_a) +
            voltage_v[step + 1] * switched_current_a
        dissipated_power_w =
            SERIES_RESISTANCE_OHM * branch.i_last^2 +
            LOAD_CONDUCTANCE_S * voltage_v[step + 1]^2 +
            arrester_power_w
        net_power_w = delivered_power_w - dissipated_power_w
        integrated_net_energy_j +=
            0.5 * step_s * (previous_net_power_w + net_power_w)
        energy_defect_j[step + 1] =
            stored_energy_j[step + 1] - stored_energy_j[1] - integrated_net_energy_j
        previous_net_power_w = net_power_w
        maximum_kcl_residual_a = max(
            maximum_kcl_residual_a,
            result.diagnostics.maximum_kcl_residual_a,
        )
        maximum_constraint_residual_v = max(
            maximum_constraint_residual_v,
            result.diagnostics.maximum_constraint_residual_v,
        )
        numeric_factorization_count += result.diagnostics.numeric_factorization_count
        iterative_refinement_count += result.diagnostics.iterative_refinement_count
        symbolic_factorization_count += result.diagnostics.symbolic_factorization_count
        factor_reuse_count += result.diagnostics.factor_reuse_count
        push!(increment_history, voltage_v[step + 1] - voltage_v[step])

        if restart_step !== nothing && step == restart_step
            checkpoint = nonlinear_nodal_checkpoint(system)
            checkpoint_increments = copy(increment_history)
            checkpoint_voltage_identity = objectid(nonlinear_linear_system(system).v)
            probe = advance_nonlinear_step!(
                system,
                time_s[step + 2],
                step_s,
            )
            probe.accepted || error("restart probe step failed: $(probe.failure)")
            probe_voltage_v = probe.voltage_v[2]
            restore_nonlinear_nodal_checkpoint!(system, checkpoint)
            increment_history = checkpoint_increments
            objectid(nonlinear_linear_system(system).v) == checkpoint_voltage_identity ||
                error("checkpoint restore replaced the accepted voltage buffer")
        end
    end
    return (;
        time_s,
        voltage_v,
        constraint_current_a,
        branch_current_a,
        nonlinear_device_power_w,
        stored_energy_j,
        energy_defect_j,
        maximum_kcl_residual_a,
        maximum_constraint_residual_v,
        minimum_arrester_power_w,
        maximum_nonlinear_power_diagnostic_error_w,
        localized_discontinuity_count,
        localized_event_chatter_veto_count,
        physical_chatter_veto_count,
        numeric_factorization_count,
        iterative_refinement_count,
        symbolic_factorization_count,
        factor_reuse_count,
        probe_voltage_v,
    )
end

function typed_study_run(step_s::Float64)
    system, _branch, _fit = nonlinear_network()
    schedule = NonlinearEMTStudySchedule(
        step_s,
        FINAL_TIME_S;
        discontinuities=[
            NonlinearEMTDiscontinuity(step_s, :localized_event),
            NonlinearEMTDiscontinuity(EVENT_TIME_S, :localized_event),
        ],
    )
    return evaluate_nonlinear_emt_network!(system, schedule)
end

function manufactured_voltage_v(node::Int, time_s::Float64)
    base_voltage_v = 0.5 + 0.1 * node
    participation = 1.0 - (node - 1) / (MANUFACTURED_NODE_COUNT - 1)
    time_s < MANUFACTURED_EVENT_TIME_S && return base_voltage_v
    return base_voltage_v + participation * (
        MANUFACTURED_EVENT_JUMP_V +
        MANUFACTURED_POST_EVENT_RAMP_V_PER_S *
            (time_s - MANUFACTURED_EVENT_TIME_S)
    )
end

function manufactured_source_current_a(
    node::Int,
    time_s::Float64,
    ground_conductance_s::Float64,
    nonlinear_conductance_s::Float64,
    cubic_coefficient_a_per_v3::Float64,
)
    voltage_v = manufactured_voltage_v(node, time_s)
    source_current_a = (ground_conductance_s + nonlinear_conductance_s) * voltage_v +
        cubic_coefficient_a_per_v3 * voltage_v^3
    if time_s >= MANUFACTURED_EVENT_TIME_S && node <= 2
        other_node = node == 1 ? 2 : 1
        source_current_a += MANUFACTURED_SWITCH_CONDUCTANCE_S *
            (voltage_v - manufactured_voltage_v(other_node, time_s))
    end
    return source_current_a
end

function manufactured_topology_run(step_s::Float64)
    elements = AIMORA.Branches.EMTElement[]
    devices = CubicCurrentBranch[]
    for node in 1:MANUFACTURED_NODE_COUNT
        ground_conductance_s = 0.45 + 0.05 * node
        nonlinear_conductance_s = 0.02
        cubic_coefficient_a_per_v3 = 0.002
        push!(elements, ConductanceBranch(node, 0, ground_conductance_s))
        let node=node,
            ground_conductance_s=ground_conductance_s,
            nonlinear_conductance_s=nonlinear_conductance_s,
            cubic_coefficient_a_per_v3=cubic_coefficient_a_per_v3
            push!(elements, CurrentInjection(
                node,
                time_s -> manufactured_source_current_a(
                    node,
                    time_s,
                    ground_conductance_s,
                    nonlinear_conductance_s,
                    cubic_coefficient_a_per_v3,
                ),
            ))
        end
        push!(devices, CubicCurrentBranch(
            node,
            0;
            linear_conductance_s=nonlinear_conductance_s,
            cubic_coefficient_a_per_v3,
        ))
    end
    push!(elements, TimeSwitch(
        1,
        2;
        close_time_s=MANUFACTURED_EVENT_TIME_S,
        on_conductance=MANUFACTURED_SWITCH_CONDUCTANCE_S,
        off_conductance=0.0,
    ))
    source_scales_a = [
        maximum(abs(manufactured_source_current_a(
            node,
            time_s,
            0.45 + 0.05 * node,
            0.02,
            0.002,
        )) for time_s in (
            0.0,
            prevfloat(MANUFACTURED_EVENT_TIME_S),
            MANUFACTURED_EVENT_TIME_S,
            MANUFACTURED_FINAL_TIME_S,
        ))
        for node in 1:MANUFACTURED_NODE_COUNT
    ]
    initial_voltage_v = [
        manufactured_voltage_v(node, 0.0)
        for node in 1:MANUFACTURED_NODE_COUNT
    ]
    linear_system = NodalSystem(MANUFACTURED_NODE_COUNT, elements)
    linear_system.v .= initial_voltage_v
    system = NonlinearNodalSystem(
        linear_system,
        devices;
        ideal_constraints=[IdealVoltageConstraint(
            (MANUFACTURED_NODE_COUNT,),
            (1.0,),
            initial_voltage_v[end],
        )],
        scales=NonlinearNetworkScales(
            initial_voltage_v,
            source_scales_a,
            [initial_voltage_v[end]],
            [maximum(source_scales_a)],
        ),
        options=NonlinearSolveOptions(sparse_dimension_threshold=1),
    )
    schedule = NonlinearEMTStudySchedule(
        step_s,
        MANUFACTURED_FINAL_TIME_S;
        discontinuities=[NonlinearEMTDiscontinuity(
            MANUFACTURED_EVENT_TIME_S,
            :topology_change,
        )],
    )
    trace = evaluate_nonlinear_emt_network!(system, schedule)
    event_step = round(Int, MANUFACTURED_EVENT_TIME_S / step_s)
    exact_voltage_v = [
        manufactured_voltage_v(node, time_s)
        for node in 1:MANUFACTURED_NODE_COUNT,
            time_s in trace.time_s[2:end]
    ]
    maximum_voltage_error_v = maximum(
        abs,
        trace.voltage_v[:, 2:end] .- exact_voltage_v,
    )
    maximum_constraint_current_a = maximum(
        abs,
        trace.constraint_current_a[:, 2:end];
        init=0.0,
    )
    event_step > 1 || error("manufactured topology event requires a pre-event step")
    pre_event_signature = trace.diagnostics[event_step - 1].topology_signature
    event_diagnostics = trace.diagnostics[event_step]
    post_event_diagnostics = trace.diagnostics[event_step + 1]
    event_diagnostics.topology_signature != pre_event_signature || error(
        "manufactured topology event did not invalidate the sparse structural signature",
    )
    event_diagnostics.symbolic_factorization_count == 1 || error(
        "manufactured topology event did not rebuild one sparse symbolic factorization",
    )
    post_event_diagnostics.symbolic_factorization_count == 0 &&
        post_event_diagnostics.factor_reuse_count >= 1 || error(
            "manufactured post-event solve did not reuse the sparse symbolic factorization",
        )
    maximum_voltage_error_v <= 5.0e-12 || error(
        "manufactured eight-node voltage error is $maximum_voltage_error_v V",
    )
    maximum_constraint_current_a <= 2.0e-12 || error(
        "manufactured eight-node ideal-constraint current is $maximum_constraint_current_a A",
    )
    return (;
        trace,
        exact_voltage_v,
        maximum_voltage_error_v,
        maximum_constraint_current_a,
        event_step,
        pre_event_signature,
        event_signature=event_diagnostics.topology_signature,
    )
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    coarse = network_run(20.0e-6)
    medium = network_run(10.0e-6)
    typed_medium = typed_study_run(10.0e-6)
    fine = network_run(5.0e-6)
    restarted = network_run(10.0e-6; restart_step=100)
    manufactured = manufactured_topology_run(10.0e-6)
    medium_restart_error_v = restarted.voltage_v .- medium.voltage_v
    maximum_restart_error_v = maximum(abs, medium_restart_error_v)
    maximum_restart_error_v == 0.0 || error(
        "checkpoint continuation differs from uninterrupted execution by $maximum_restart_error_v V",
    )
    typed_medium_voltage_v = vec(typed_medium.voltage_v[2, :])
    typed_medium_constraint_current_a = vec(typed_medium.constraint_current_a[1, :])
    reinterpret(UInt64, typed_medium_voltage_v) == reinterpret(UInt64, medium.voltage_v) ||
        error("typed nonlinear EMT study voltage differs from the manual physical-accounting path")
    maximum_typed_constraint_error_a = maximum(
        abs,
        typed_medium_constraint_current_a .- medium.constraint_current_a,
    )
    maximum_typed_constraint_error_a <= 2.0e-15 || error(
        "typed nonlinear EMT study constraint current differs by $maximum_typed_constraint_error_a A",
    )
    typed_discontinuity_reasons =
        getproperty.(typed_medium.diagnostics, :discontinuity_reason)
    findall(!=(:none), typed_discontinuity_reasons) == [1, round(Int, EVENT_TIME_S / 10.0e-6)] ||
        error("typed nonlinear EMT study did not preserve the declared discontinuity order")
    coarse_medium_error_v = maximum(
        abs,
        coarse.voltage_v .- medium.voltage_v[1:2:end],
    )
    medium_fine_error_v = maximum(
        abs,
        medium.voltage_v .- fine.voltage_v[1:2:end],
    )
    refinement_ratio = coarse_medium_error_v / medium_fine_error_v
    relative_energy_defect = abs(fine.energy_defect_j[end]) /
        max(maximum(fine.stored_energy_j), eps(Float64))
    refinement_ratio > 2.0 || error(
        "nonlinear waveform refinement ratio $refinement_ratio does not show the expected convergent envelope",
    )
    fine.maximum_kcl_residual_a <= 1.1e-9 || error(
        "nonlinear network KCL residual exceeds its scaled physical tolerance",
    )
    fine.maximum_constraint_residual_v <= 1.0e-12 || error(
        "ideal source constraint residual exceeds its physical tolerance",
    )
    fine.minimum_arrester_power_w >= -1.0e-14 || error(
        "fitted ZnO branch violates the declared passive power sign",
    )
    fine.maximum_nonlinear_power_diagnostic_error_w <= 2.0e-12 || error(
        "solver nonlinear-device power diagnostic disagrees with the independently evaluated ZnO power",
    )
    relative_energy_defect <= 1.0e-3 || error(
        "nonlinear RLC energy defect $relative_energy_defect exceeds the declared case limit",
    )
    fine.localized_discontinuity_count == 2 || error(
        "nonlinear case did not treat both declared localized discontinuities",
    )
    fine.localized_event_chatter_veto_count == 1 || error(
        "localized switching event was not distinguished from numerical chatter",
    )
    coarse_aligned_medium_v = medium.voltage_v[1:2:end]
    coarse_aligned_fine_v = fine.voltage_v[1:4:end]

    waveform_csv = write_series_csv(
        joinpath(output_dir, "waveform.csv"),
        "time_s",
        fine.time_s,
        [
            "load_voltage_v" => fine.voltage_v,
            "series_current_a" => fine.branch_current_a,
            "nonlinear_device_power_w" => fine.nonlinear_device_power_w,
            "stored_energy_j" => fine.stored_energy_j,
            "energy_defect_j" => fine.energy_defect_j,
        ],
    )
    convergence_csv = write_series_csv(
        joinpath(output_dir, "convergence.csv"),
        "time_s",
        coarse.time_s,
        [
            "coarse_voltage_v" => coarse.voltage_v,
            "medium_voltage_v" => coarse_aligned_medium_v,
            "fine_voltage_v" => coarse_aligned_fine_v,
        ],
    )
    restart_csv = write_series_csv(
        joinpath(output_dir, "restart_comparison.csv"),
        "time_s",
        medium.time_s,
        [
            "uninterrupted_voltage_v" => medium.voltage_v,
            "restored_voltage_v" => restarted.voltage_v,
            "difference_v" => medium_restart_error_v,
        ],
    )
    manufactured_csv = write_series_csv(
        joinpath(output_dir, "manufactured_topology.csv"),
        "time_s",
        manufactured.trace.time_s,
        [
            "node_$(node)_voltage_v" => vec(manufactured.trace.voltage_v[node, :])
            for node in 1:MANUFACTURED_NODE_COUNT
        ],
    )
    waveform_svg = write_waveform_svg(
        joinpath(output_dir, "waveform.svg"),
        fine.time_s,
        [
            "load voltage" => fine.voltage_v,
            "RLC current x 100" => 100.0 .* fine.branch_current_a,
        ];
        title="Nonlinear RLC Discontinuity Response",
        y_label="voltage (V) and scaled current",
    )
    summary = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Nonlinear Network Discontinuity",
        (
            voltage_steps_s=(20.0e-6, 10.0e-6, 5.0e-6),
            coarse_to_medium_maximum_error_v=coarse_medium_error_v,
            medium_to_fine_maximum_error_v=medium_fine_error_v,
            refinement_error_ratio=refinement_ratio,
            maximum_kcl_residual_a=fine.maximum_kcl_residual_a,
            maximum_constraint_residual_v=fine.maximum_constraint_residual_v,
            final_energy_defect_j=fine.energy_defect_j[end],
            relative_final_energy_defect=relative_energy_defect,
            minimum_arrester_power_w=fine.minimum_arrester_power_w,
            maximum_nonlinear_power_diagnostic_error_w=
                fine.maximum_nonlinear_power_diagnostic_error_w,
            localized_discontinuity_count=fine.localized_discontinuity_count,
            localized_event_chatter_veto_count=
                fine.localized_event_chatter_veto_count,
            physical_chatter_veto_count=fine.physical_chatter_veto_count,
            numeric_factorization_count=fine.numeric_factorization_count,
            iterative_refinement_count=fine.iterative_refinement_count,
            symbolic_factorization_count=fine.symbolic_factorization_count,
            factor_reuse_count=fine.factor_reuse_count,
            maximum_restart_error_v,
            maximum_typed_study_voltage_error_v=0.0,
            maximum_typed_constraint_error_a,
            manufactured_node_count=MANUFACTURED_NODE_COUNT,
            manufactured_event_time_s=MANUFACTURED_EVENT_TIME_S,
            manufactured_maximum_voltage_error_v=
                manufactured.maximum_voltage_error_v,
            manufactured_maximum_constraint_current_a=
                manufactured.maximum_constraint_current_a,
            manufactured_pre_event_topology_signature=
                manufactured.pre_event_signature,
            manufactured_event_topology_signature=manufactured.event_signature,
            restart_probe_voltage_v=restarted.probe_voltage_v,
            public_case_domain="synthetic instantaneous-EMT network only",
            commercial_tool_equivalence=false,
        ),
    )
    @printf("Waveform CSV: %s\n", waveform_csv)
    @printf("Convergence CSV: %s\n", convergence_csv)
    @printf("Restart CSV: %s\n", restart_csv)
    @printf("Manufactured topology CSV: %s\n", manufactured_csv)
    @printf("Waveform: %s\n", waveform_svg)
    @printf("Summary: %s\n", summary)
end

main()
