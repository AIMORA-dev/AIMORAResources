#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using .ExampleSupport

function recorded_indices(sample_count::Int; maximum_samples::Int = 3_001)
    sample_count > 0 || throw(ArgumentError("converter trace must contain samples"))
    stride = max(1, cld(sample_count - 1, maximum_samples - 1))
    indices = collect(1:stride:sample_count)
    last(indices) == sample_count || push!(indices, sample_count)
    return indices
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    trace = AIMORA.EMTStudy.simulate_three_phase_vsc()
    metrics = trace.metrics
    parameters = trace.parameters
    zero_sequence_current = vec(sum(trace.filter_current_a; dims = 1))
    maximum_zero_sequence_current_a = maximum(abs, zero_sequence_current)
    active_power_tracking_error = abs(
        metrics.mean_active_power_w - parameters.active_power_reference_w,
    ) / abs(parameters.active_power_reference_w)
    maximum_phase_current_thd = maximum(metrics.harmonic.phase_current_thd)
    maximum_line_voltage_thd = maximum(metrics.harmonic.line_voltage_thd)
    metrics.finite_output && metrics.exact_boundary_alignment &&
        metrics.boundary_count == 6 && metrics.block_count == 1 &&
        metrics.restart_count == 1 && metrics.commutation_count > 0 &&
        metrics.maximum_topology_iterations <= 12 &&
        metrics.shoot_through_rejection_count == 0 &&
        metrics.all_off_dead_time_sample_count > 0 &&
        metrics.antiparallel_diode_sample_count > 0 &&
        active_power_tracking_error <= 0.03 &&
        abs(metrics.mean_reactive_power_var) <= 500.0 &&
        760.0 <= metrics.dc_link_mean_voltage_v <= 800.0 &&
        metrics.dc_link_peak_to_peak_ripple_v <= 5.0 &&
        maximum_phase_current_thd <= 0.05 &&
        maximum_line_voltage_thd <= 0.03 &&
        metrics.maximum_nodal_kcl_residual_a <= 1.0e-7 &&
        metrics.relative_energy_residual <= 1.0e-5 &&
        metrics.relative_dc_ac_energy_residual <= 1.0e-5 &&
        maximum_zero_sequence_current_a <= 1.0e-7 ||
        error("switch-detailed three-phase VSC acceptance checks failed")

    indices = recorded_indices(length(trace.time_s))
    time_s = trace.time_s[indices]
    waveform_csv = write_series_csv(
        joinpath(output_dir, "three_phase_vsc_waveforms.csv"),
        "time_s",
        time_s,
        [
            "dc_link_voltage_v" => trace.dc_link_voltage_v[indices],
            "active_power_w" => trace.active_power_w[indices],
            "reactive_power_var" => trace.reactive_power_var[indices],
            "phase_a_current_a" => trace.filter_current_a[1, indices],
            "phase_b_current_a" => trace.filter_current_a[2, indices],
            "phase_c_current_a" => trace.filter_current_a[3, indices],
            "line_ab_voltage_v" => trace.line_voltage_v[1, indices],
            "line_bc_voltage_v" => trace.line_voltage_v[2, indices],
            "line_ca_voltage_v" => trace.line_voltage_v[3, indices],
            "blocked" => trace.blocked[indices],
        ],
    )
    device_csv = write_series_csv(
        joinpath(output_dir, "three_phase_vsc_device_states.csv"),
        "time_s",
        time_s,
        [
            "phase_a_duty" => trace.duty[1, indices],
            "phase_b_duty" => trace.duty[2, indices],
            "phase_c_duty" => trace.duty[3, indices],
            "phase_a_upper_gate" => trace.upper_gate_applied[1, indices],
            "phase_a_lower_gate" => trace.lower_gate_applied[1, indices],
            "phase_b_upper_gate" => trace.upper_gate_applied[2, indices],
            "phase_b_lower_gate" => trace.lower_gate_applied[2, indices],
            "phase_c_upper_gate" => trace.upper_gate_applied[3, indices],
            "phase_c_lower_gate" => trace.lower_gate_applied[3, indices],
            "upper_antiparallel_diode_count" => vec(sum(
                trace.upper_antiparallel_diode_conducting[:, indices];
                dims = 1,
            )),
            "lower_antiparallel_diode_count" => vec(sum(
                trace.lower_antiparallel_diode_conducting[:, indices];
                dims = 1,
            )),
        ],
    )
    current_svg = write_waveform_svg(
        joinpath(output_dir, "three_phase_vsc_currents.svg"),
        time_s,
        [
            "phase_a_current_a" => trace.filter_current_a[1, indices],
            "phase_b_current_a" => trace.filter_current_a[2, indices],
            "phase_c_current_a" => trace.filter_current_a[3, indices],
        ];
        title = "Switch-Detailed Three-Phase VSC Filter Currents",
        y_label = "current (A)",
    )
    dc_svg = write_waveform_svg(
        joinpath(output_dir, "three_phase_vsc_dc_link.svg"),
        time_s,
        ["dc_link_voltage_v" => trace.dc_link_voltage_v[indices]];
        title = "Switch-Detailed Three-Phase VSC DC Link",
        y_label = "voltage (V)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Switch-Detailed Three-Phase Two-Level VSC",
        (
            julia_only = true,
            fidelity = "SwitchingDetailed",
            topology = "three-phase three-wire two-level IGBT bridge",
            control_family = "known-angle synchronous-reference-frame grid-following current PI",
            modulation = "minimum-maximum zero-sequence-injected trailing-edge PWM (centered-space-vector-equivalent line voltages in the linear region)",
            filter_and_transformer = "series L filter plus grounded-wye transformer leakage referred to converter side",
            timestep_s = parameters.timestep_s,
            duration_s = parameters.end_time_s,
            carrier_frequency_hz = parameters.carrier_frequency_hz,
            control_period_s = parameters.control_period_s,
            control_delay_s = parameters.control_delay_s,
            active_power_reference_w = parameters.active_power_reference_w,
            mean_active_power_w = metrics.mean_active_power_w,
            active_power_tracking_error = active_power_tracking_error,
            reactive_power_reference_var = parameters.reactive_power_reference_var,
            mean_reactive_power_var = metrics.mean_reactive_power_var,
            dc_link_mean_voltage_v = metrics.dc_link_mean_voltage_v,
            dc_link_peak_to_peak_ripple_v = metrics.dc_link_peak_to_peak_ripple_v,
            phase_current_fundamental_rms_a = join(metrics.harmonic.phase_current_fundamental_rms_a, ","),
            phase_current_thd = join(metrics.harmonic.phase_current_thd, ","),
            line_voltage_fundamental_rms_v = join(metrics.harmonic.line_voltage_fundamental_rms_v, ","),
            line_voltage_thd = join(metrics.harmonic.line_voltage_thd, ","),
            maximum_zero_sequence_current_a = maximum_zero_sequence_current_a,
            maximum_nodal_kcl_residual_a = metrics.maximum_nodal_kcl_residual_a,
            dc_source_energy_j = metrics.dc_source_energy_j,
            ac_terminal_energy_j = metrics.ac_terminal_energy_j,
            converter_dissipated_energy_j = metrics.converter_dissipated_energy_j,
            dc_ac_energy_residual_j = metrics.dc_ac_energy_residual_j,
            relative_dc_ac_energy_residual = metrics.relative_dc_ac_energy_residual,
            relative_energy_residual = metrics.relative_energy_residual,
            control_sample_count = metrics.control_sample_count,
            control_write_count = metrics.control_write_count,
            pwm_cycle_counts = join(metrics.pwm_cycle_counts, ","),
            pwm_edge_counts = join(metrics.pwm_edge_counts, ","),
            commutation_count = metrics.commutation_count,
            maximum_topology_iterations = metrics.maximum_topology_iterations,
            all_off_dead_time_sample_count = metrics.all_off_dead_time_sample_count,
            antiparallel_diode_sample_count = metrics.antiparallel_diode_sample_count,
            block_count = metrics.block_count,
            restart_count = metrics.restart_count,
            boundary_count = metrics.boundary_count,
            exact_boundary_alignment = metrics.exact_boundary_alignment,
            unsupported = "PLL dynamics, grid-forming control, four-wire zero-sequence current, LCL resonance, transformer magnetization/saturation, reverse recovery, nonlinear device capacitance, switching-energy maps, electrothermal state, manufacturer prediction, and certification",
        ),
    )
    println("Waveforms: ", waveform_csv)
    println("Device states: ", device_csv)
    println("Currents: ", current_svg)
    println("DC link: ", dc_svg)
    println("Summary: ", summary_path)
end

main()
