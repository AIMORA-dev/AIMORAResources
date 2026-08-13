module ExtendedVSCExampleSupport

using AIMORA
using ..ExampleSupport

export run_extended_vsc_public_case

const VSC = AIMORA.SwitchDetailedVSC
const EMT = AIMORA.EMTStudy

function recorded_indices(sample_count::Int; maximum_samples::Int=2_001)
    sample_count > 0 || throw(ArgumentError("extended VSC trace must contain samples"))
    stride = max(1, cld(sample_count - 1, maximum_samples - 1))
    indices = collect(1:stride:sample_count)
    last(indices) == sample_count || push!(indices, sample_count)
    return indices
end

function operating_mode_value(mode)
    mode === VSC.VSCNormalOperation && return 0.0
    mode === VSC.VSCCurrentLimitedOperation && return 1.0
    mode === VSC.VSCBlockedOperation && return 2.0
    error("unknown extended VSC operating mode")
end

function request_disposition_value(disposition)
    disposition === VSC.VSCPlantRequestApplied && return 0.0
    disposition === VSC.VSCPlantRequestLimited && return 1.0
    disposition === VSC.VSCPlantRequestStale && return 2.0
    disposition === VSC.VSCPlantRequestRefused && return 3.0
    error("unknown extended VSC plant-request disposition")
end

function validate_public_trace(trace)
    metrics = trace.metrics
    metrics.finite_output || error("extended VSC public case produced nonfinite output")
    metrics.exact_boundary_alignment || error("extended VSC boundary was not tick-aligned")
    metrics.maximum_nodal_kcl_residual_a <= 1.0e-7 ||
        error("extended VSC nodal KCL residual exceeded tolerance")
    metrics.maximum_nonlinear_kcl_residual_a <= 1.0e-7 ||
        error("extended VSC nonlinear KCL residual exceeded tolerance")
    metrics.maximum_terminal_kcl_residual_a <= 1.0e-10 ||
        error("extended VSC terminal KCL residual exceeded tolerance")
    metrics.maximum_neutral_kcl_residual_a <= 1.0e-7 ||
        error("extended VSC neutral KCL residual exceeded tolerance")
    metrics.relative_energy_residual <= 1.0e-6 ||
        error("extended VSC energy residual exceeded tolerance")
    metrics.sequence_extractor_settled ||
        error("extended VSC sequence extractor did not settle")
    all(isfinite, trace.active_power_w) || error("nonfinite active-power trace")
    all(isfinite, trace.controller_frequency_hz) ||
        error("nonfinite controller-frequency trace")
    return trace
end

function run_extended_vsc_public_case(
    slug::AbstractString,
    title::AbstractString,
    controller_family::VSC.ExtendedVSCControllerFamily,
    filter_family::VSC.ExtendedVSCFilterFamily,
    wire_form::VSC.ExtendedVSCWireForm,
    args=ARGS,
)
    AIMORA.require_solver()
    scenario = VSC.ExtendedVSCScenarioParameters(
        zero_sequence_voltage_ratio=wire_form === VSC.FourWireForm ? 0.03 : 0.0,
    )
    controller = controller_family === VSC.StationaryResonantGridFollowing ?
        VSC.ExtendedVSCControlParameters(
            family=controller_family,
            resonant_gain_v_per_a=5.0,
        ) : VSC.ExtendedVSCControlParameters(family=controller_family)
    filter = controller_family === VSC.StationaryResonantGridFollowing ?
        VSC.ExtendedVSCFilterParameters(
            family=filter_family,
            shunt_damping_conductance_s=0.1,
        ) : VSC.ExtendedVSCFilterParameters(family=filter_family)
    protection = controller_family === VSC.VirtualSynchronousGridForming ?
        VSC.ExtendedVSCProtectionParameters(
            ac_overcurrent_a=500.0,
            dc_undervoltage_v=500.0,
            dc_overvoltage_v=1200.0,
            minimum_frequency_hz=40.0,
            maximum_frequency_hz=70.0,
            minimum_phase_rms_voltage_v=50.0,
            maximum_phase_rms_voltage_v=600.0,
        ) : VSC.ExtendedVSCProtectionParameters()
    parameters = VSC.ExtendedVSCParameters(
        controller=controller,
        filter=filter,
        wire_form=wire_form,
        protection=protection,
        scenario=scenario,
    )
    plant_request = controller_family === VSC.StationaryResonantGridFollowing ?
        VSC.ExtendedVSCPlantRequest(
            available_active_power_w=parameters.rated_power_va,
            active_power_reference_w=5.0e3,
        ) : VSC.ExtendedVSCPlantRequest(
            available_active_power_w=parameters.rated_power_va,
        )
    trace = validate_public_trace(EMT.simulate_extended_vsc(
        parameters;
        plant_request,
    ))
    indices = recorded_indices(length(trace.time_s))
    time_s = trace.time_s[indices]
    output_dir = artifact_directory(
        args,
        joinpath(dirname(abspath(PROGRAM_FILE)), "outputs"),
    )
    csv_path = write_series_csv(
        joinpath(output_dir, "$(slug).csv"),
        "time_s",
        time_s,
        [
            "phase_a_grid_voltage_v" => trace.grid_voltage_v[1, indices],
            "phase_a_grid_current_a" => trace.grid_current_a[1, indices],
            "phase_b_grid_current_a" => trace.grid_current_a[2, indices],
            "phase_c_grid_current_a" => trace.grid_current_a[3, indices],
            "neutral_current_a" => trace.neutral_current_a[indices],
            "dc_link_voltage_v" => trace.dc_link_voltage_v[indices],
            "active_power_w" => trace.active_power_w[indices],
            "reactive_power_var" => trace.reactive_power_var[indices],
            "positive_sequence_voltage_v" => trace.positive_sequence_voltage_v[indices],
            "negative_sequence_voltage_v" => trace.negative_sequence_voltage_v[indices],
            "zero_sequence_voltage_v" => trace.zero_sequence_voltage_v[indices],
            "controller_frequency_hz" => trace.controller_frequency_hz[indices],
            "phase_a_duty" => trace.duty[1, indices],
            "operating_mode" => operating_mode_value.(trace.operating_mode[indices]),
            "request_disposition" => request_disposition_value.(
                trace.request_disposition[indices],
            ),
        ],
    )
    current_svg_path = write_waveform_svg(
        joinpath(output_dir, "$(slug)_currents.svg"),
        time_s,
        [
            "phase_a" => trace.grid_current_a[1, indices],
            "phase_b" => trace.grid_current_a[2, indices],
            "phase_c" => trace.grid_current_a[3, indices],
            "neutral" => trace.neutral_current_a[indices],
        ];
        title="$title Grid and Neutral Currents",
        y_label="current (A)",
    )
    response_svg_path = write_waveform_svg(
        joinpath(output_dir, "$(slug)_response.svg"),
        time_s,
        [
            "dc_link_voltage_v" => trace.dc_link_voltage_v[indices],
            "positive_sequence_v" => trace.positive_sequence_voltage_v[indices],
            "negative_sequence_v" => trace.negative_sequence_voltage_v[indices],
            "zero_sequence_v" => trace.zero_sequence_voltage_v[indices],
        ];
        title="$title DC and Sequence Response",
        y_label="voltage (V)",
    )
    final = last(indices)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        title,
        (
            julia_only=true,
            fidelity="InstantaneousEMT carrier-switching-detailed two-level B200/D200 VSC",
            controller_family=controller_family,
            filter_family=filter_family,
            wire_form=wire_form,
            timestep_s=parameters.timestep_s,
            duration_s=parameters.scenario.end_time_s,
            carrier_frequency_hz=parameters.carrier_frequency_hz,
            control_period_s=parameters.controller.control_period_s,
            control_delay_s=parameters.controller.control_delay_s,
            final_dc_link_voltage_v=trace.dc_link_voltage_v[final],
            final_active_power_w=trace.active_power_w[final],
            final_reactive_power_var=trace.reactive_power_var[final],
            maximum_phase_current_a=trace.metrics.maximum_phase_current_a,
            maximum_neutral_kcl_residual_a=trace.metrics.maximum_neutral_kcl_residual_a,
            maximum_nodal_kcl_residual_a=trace.metrics.maximum_nodal_kcl_residual_a,
            maximum_nonlinear_kcl_residual_a=trace.metrics.maximum_nonlinear_kcl_residual_a,
            relative_energy_residual=trace.metrics.relative_energy_residual,
            controller_sample_count=trace.metrics.controller_sample_count,
            controller_write_count=trace.metrics.controller_write_count,
            task_occurrence_count=trace.metrics.task_occurrence_count,
            boundary_count=trace.metrics.boundary_count,
            protection_trip_count=trace.metrics.protection_trip_count,
            protection_restart_count=trace.metrics.protection_restart_count,
            bridge_transition_count=trace.metrics.bridge_transition_count,
            deterministic_signature=trace.metrics.deterministic_signature,
            manufacturer_identity="none",
            private_solver_required=true,
            unsupported="vendor or grid-code parameters, standard conformance, arbitrary user controllers, average-value substitution, transformer saturation, destructive failure, ATP/PSCAD equivalence, HIL, and certification",
        ),
    )
    println(csv_path)
    println(current_svg_path)
    println(response_svg_path)
    println(summary_path)
    return nothing
end

end
