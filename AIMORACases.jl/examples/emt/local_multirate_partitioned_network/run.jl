#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(
    @__DIR__,
    "..",
    "..",
    "support",
    "LocalMultiratePartitionedNetwork.jl",
)))

using AIMORA
using AIMORA.EMTPartitioning
using AIMORA.EMTTaskPlatform
using .ExampleSupport
using .LocalMultiratePartitionedNetwork

const PASSIVE_PARAMETERS = (
    source_voltage_v=120.0,
    source_resistance_ohm=0.8,
    source_inductance_h=0.015,
    load_resistance_ohm=12.0,
    load_capacitance_f=2.0e-4,
    initial_source_current_a=0.0,
    initial_interface_voltage_v=0.0,
)

function passive_two_region_study(
    communication_step;
    source_rate::Int,
    load_rate::Int,
    method::EMTPartitionExchangeMethod,
)
    stop = emt_logical_time(160 // 1_000_000)
    regions = (
        EMTPartitionRegion(
            "source",
            ("source_rl",),
            LocalMultiratePartitionedNetwork.logical_substep(
                communication_step,
                source_rate,
            ),
        ),
        EMTPartitionRegion(
            "load",
            ("load_rc",),
            LocalMultiratePartitionedNetwork.logical_substep(
                communication_step,
                load_rate,
            ),
        ),
    )
    port = EMTInterfacePort(
        "passive_interface",
        VoltageCurrentInterfacePort,
        "source",
        "load",
        "source_terminal",
        "load_terminal";
        voltage_base_v=120.0,
        current_base_a=10.0,
        reference_impedance_ohm=12.0,
    )
    plan = emt_partition_plan(
        regions,
        (port,);
        start=emt_logical_time(0),
        stop,
        communication_step,
        exchange=EMTPartitionExchangePolicy(method),
    )
    return PassiveTwoRegionRLCStudy(plan; PASSIVE_PARAMETERS...)
end

function execute(study)
    return AIMORA.execute_partitioned_emt!(AIMORA.prepare_partitioned_emt(study))
end

function passive_refinement()
    equal_step = execute(passive_two_region_study(
        emt_logical_time(5 // 4_000_000);
        source_rate=1,
        load_rate=1,
        method=DirectCoupledExchange,
    ))
    settings = (
        (emt_logical_time(5 // 1_000_000), 4, 1),
        (emt_logical_time(5 // 2_000_000), 2, 1),
        (emt_logical_time(5 // 4_000_000), 1, 1),
    )
    results = map(settings) do (communication_step, source_rate, load_rate)
        execute(passive_two_region_study(
            communication_step;
            source_rate,
            load_rate,
            method=IteratedWaveformExchange,
        ))
    end
    all(result -> result.accepted, results) || error(
        "one passive two-region refinement was not accepted",
    )
    current_scale = max(abs(equal_step.source_current_a[end]), 1.0)
    voltage_scale = max(abs(equal_step.interface_voltage_v[end]), 1.0)
    endpoint_errors = map(results) do result
        hypot(
            (result.source_current_a[end] - equal_step.source_current_a[end]) /
                current_scale,
            (result.interface_voltage_v[end] -
             equal_step.interface_voltage_v[end]) / voltage_scale,
        )
    end
    all(diff(collect(endpoint_errors)) .< 0.0) || error(
        "passive communication refinement did not reduce endpoint error",
    )
    last(endpoint_errors) <= 2.0e-5 || error(
        "passive partition limit disagrees with direct equal-step execution",
    )
    return (; results, equal_step, endpoint_errors)
end

function synchronization_trace_error(reference, candidate)
    maximum_error_v = 0.0
    for (candidate_index, time_s) in enumerate(candidate.time_s)
        reference_index = searchsortedfirst(reference.time_s, time_s)
        reference_index <= length(reference.time_s) || error(
            "refined trace omits synchronization time $time_s",
        )
        isapprox(
            reference.time_s[reference_index],
            time_s;
            atol=16eps(max(abs(time_s), 1.0)),
            rtol=0.0,
        ) || error("refined and candidate synchronization clocks differ")
        maximum_error_v = max(
            maximum_error_v,
            maximum(abs,
                candidate.positive_terminal_voltage_v[:, candidate_index] .-
                reference.positive_terminal_voltage_v[:, reference_index],
            ),
            maximum(abs,
                candidate.negative_terminal_voltage_v[:, candidate_index] .-
                reference.negative_terminal_voltage_v[:, reference_index],
            ),
        )
    end
    return maximum_error_v
end

function coupled_results()
    accepted_study = coupled_partition_study()
    accepted_prepared = AIMORA.prepare_partitioned_emt(accepted_study)
    AIMORA.advance_partitioned_emt!(accepted_prepared)
    AIMORA.advance_partitioned_emt!(accepted_prepared)
    checkpoint = AIMORA.partitioned_emt_checkpoint(accepted_prepared)
    accepted = AIMORA.execute_partitioned_emt!(accepted_prepared)

    restarted = AIMORA.prepare_partitioned_emt(accepted_study)
    AIMORA.restore_partitioned_emt_checkpoint!(restarted, checkpoint)
    restarted_result = AIMORA.execute_partitioned_emt!(restarted)
    accepted.deterministic_signature_sha256 ==
        restarted_result.deterministic_signature_sha256 || error(
            "coupled split restart changed the deterministic result",
        )
    for field in fieldnames(typeof(accepted))
        getfield(accepted, field) == getfield(restarted_result, field) || error(
            "coupled split restart changed result field $field",
        )
    end

    equal_step_limit = execute(coupled_partition_study(
        communication_step=emt_logical_time(1 // 400_000),
        rate_ratios=ntuple(_ -> 1, 8),
    ))
    accepted.accepted && equal_step_limit.accepted || error(
        "the event-synchronous coupled partition boundary was not accepted",
    )
    accepted_error_v = synchronization_trace_error(equal_step_limit, accepted)
    accepted_error_v <= 1.2 || error(
        "coupled local-rate result exceeds its equal-step boundary",
    )

    coarse_study = coupled_partition_study(
        communication_step=emt_logical_time(1 // 100_000),
        rate_ratios=(4, 4, 4, 2, 4, 4, 2, 1),
    )
    coarse_prepared = AIMORA.prepare_partitioned_emt(coarse_study)
    AIMORA.advance_partitioned_emt!(coarse_prepared)
    AIMORA.advance_partitioned_emt!(coarse_prepared)
    coarse_before = AIMORA.partitioned_emt_status(coarse_prepared)
    coarse_failure = try
        AIMORA.advance_partitioned_emt!(coarse_prepared)
        nothing
    catch failure
        failure
    end
    coarse_failure isa EMTPartitionFailure &&
        coarse_failure.code == :partition_window_rejected || error(
            "the preregistered coarse communication boundary did not refuse",
        )
    coarse_after = AIMORA.partitioned_emt_status(coarse_prepared)
    coarse_after.accepted_window_count == coarse_before.accepted_window_count &&
        coarse_after.time_s == coarse_before.time_s &&
        coarse_after.regional_local_step_counts ==
            coarse_before.regional_local_step_counts || error(
                "coarse communication refusal was not atomic",
            )
    return (;
        accepted,
        equal_step_limit,
        checkpoint,
        accepted_error_v,
        coarse_failure,
    )
end

maximum_or_zero(values) = isempty(values) ? 0.0 : maximum(abs, values)

function main()
    AIMORA.require_solver()
    output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    passive = passive_refinement()
    coupled = coupled_results()
    accepted = coupled.accepted

    interface_series = Pair{String,Vector{Float64}}[]
    for interface_index in axes(accepted.interface_current_a, 1)
        push!(
            interface_series,
            "interface_$(interface_index)_positive_voltage_v" =>
                vec(accepted.positive_terminal_voltage_v[interface_index, :]),
            "interface_$(interface_index)_negative_voltage_v" =>
                vec(accepted.negative_terminal_voltage_v[interface_index, :]),
            "interface_$(interface_index)_current_a" =>
                vec(accepted.interface_current_a[interface_index, :]),
        )
    end
    interface_csv = write_series_csv(
        joinpath(output_directory, "local_multirate_partitioned_network.csv"),
        "time_s",
        accepted.time_s,
        interface_series,
    )
    voltage_svg = write_waveform_svg(
        joinpath(output_directory, "local_partition_interface_voltage.svg"),
        accepted.time_s,
        Pair{String,Vector{Float64}}[
            "I1 positive" => vec(accepted.positive_terminal_voltage_v[1, :]),
            "I4 positive" => vec(accepted.positive_terminal_voltage_v[4, :]),
            "I7 positive" => vec(accepted.positive_terminal_voltage_v[7, :]),
            "I7 negative" => vec(accepted.negative_terminal_voltage_v[7, :]),
        ];
        title="Eight-Region Local-Multirate Interface Voltages",
        y_label="voltage (V)",
    )
    current_svg = write_waveform_svg(
        joinpath(output_directory, "local_partition_interface_current.svg"),
        accepted.time_s,
        Pair{String,Vector{Float64}}[
            "I1 current" => vec(accepted.interface_current_a[1, :]),
            "I4 current" => vec(accepted.interface_current_a[4, :]),
            "I7 current" => vec(accepted.interface_current_a[7, :]),
        ];
        title="Eight-Region Conservative Interface Currents",
        y_label="current (A)",
    )
    refinement_csv = write_series_csv(
        joinpath(output_directory, "local_partition_refinement.csv"),
        "communication_step_s",
        [1.25e-6, 2.5e-6, 5.0e-6],
        ["passive_endpoint_error" => reverse(collect(passive.endpoint_errors))],
    )
    refinement_svg = write_waveform_svg(
        joinpath(output_directory, "local_partition_refinement.svg"),
        [1.25e-6, 2.5e-6, 5.0e-6],
        ["passive endpoint error" => reverse(collect(passive.endpoint_errors))],
        title="Passive Communication-Step Refinement",
        x_label="communication step (s)",
        y_label="maximum boundary difference (V)",
    )
    summary = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Local Multirate and Partitioned EMT Network",
        (
            accepted=accepted.accepted,
            region_count=length(accepted.region_identities),
            interface_count=length(accepted.port_identities),
            distinct_local_rates=3,
            communication_step_s=2.5e-6,
            accepted_windows=accepted.accepted_window_count,
            rejected_windows=accepted.rejected_window_count,
            regional_local_steps=accepted.regional_local_step_counts,
            topology_and_machine_event_time_s=80.0e-6,
            maximum_interface_voltage_residual_v=maximum_or_zero(accepted.voltage_residual_v),
            maximum_interface_kcl_residual_a=maximum_or_zero(accepted.kcl_residual_a),
            maximum_interface_energy_defect_j=maximum_or_zero(accepted.interface_energy_defect_j),
            maximum_communication_error_estimate_v=maximum_or_zero(accepted.communication_error_estimate_v),
            passive_two_region_endpoint_errors=passive.endpoint_errors,
            accepted_to_equal_step_boundary_difference_v=coupled.accepted_error_v,
            coarse_10_microsecond_boundary_refused=true,
            split_restart_exact=true,
            checkpoint_time_s=coupled.checkpoint.time_s,
            checkpoint_signature_sha256=coupled.checkpoint.signature_sha256,
            deterministic_signature_sha256=accepted.deterministic_signature_sha256,
            private_solver_required=true,
            unsupported="automatic partition inference, noncommensurate or variable global steps, distributed protocols, network transport, GPU, DASSL, real-time/HIL, universal active-interface stability, standards, and certification",
        ),
    )
    println("Interface CSV: ", interface_csv)
    println("Refinement CSV: ", refinement_csv)
    println("Voltage SVG: ", voltage_svg)
    println("Current SVG: ", current_svg)
    println("Refinement SVG: ", refinement_svg)
    println("Summary: ", summary)
end

main()
