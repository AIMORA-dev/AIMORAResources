module ClassicEMTPExample

using Printf

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using AIMORA.LineConstantsStudy
using AIMORACases
using ..ExampleSupport

export run_classic_line_constants_example,
       run_classic_steady_state_example,
       run_classic_synchronous_machine_example,
       run_classic_transient_example,
       run_classic_universal_machine_example

const MAX_RECORDED_SAMPLES = 2_001

function _recorded_steps(step_count::Int)
    step_count >= 0 || throw(ArgumentError("step_count must be nonnegative"))
    stride = max(1, cld(step_count, MAX_RECORDED_SAMPLES - 1))
    steps = collect(0:stride:step_count)
    isempty(steps) || last(steps) == step_count || push!(steps, step_count)
    return unique!(sort!(steps))
end

function _parsed_case(id::Symbol)
    input_path = AIMORACases.case_path(id)
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    return input_path, parsed
end

function _trace_series(trace::DeckEMTTrace)
    series = Pair{String,Vector{Float64}}[]
    for (index, name) in enumerate(trace.node_names)
        push!(series, "$(name)_v_pu" => vec(trace.voltage_pu[index, :]))
    end
    for (index, name) in enumerate(trace.output_channel_names)
        push!(series, "$(name)_pu" => vec(trace.output_pu[index, :]))
    end
    return series
end

function _preferred_waveforms(trace::DeckEMTTrace, series)
    isempty(series) && throw(ArgumentError("classic EMT trace has no waveform series"))
    if !isempty(trace.output_channel_names)
        first_output = length(trace.node_names) + 1
        output_series = series[first_output:lastindex(series)]
        nonzero_outputs = filter(
            item -> maximum(abs, last(item); init = 0.0) > 0.0,
            output_series,
        )
        isempty(nonzero_outputs) ||
            return nonzero_outputs[1:min(lastindex(nonzero_outputs), 6)]
    end
    node_series = series[1:length(trace.node_names)]
    nonzero_nodes = filter(
        item -> maximum(abs, last(item); init = 0.0) > 0.0,
        node_series,
    )
    selected = isempty(nonzero_nodes) ? node_series : nonzero_nodes
    return selected[1:min(lastindex(selected), 6)]
end

function _write_trace_artifacts(
    id::Symbol,
    title::AbstractString,
    interpretation::AbstractString,
    input_path::AbstractString,
    parsed,
    trace::DeckEMTTrace,
    output_dir::AbstractString;
    calculation::AbstractString,
)
    basename = String(id)
    series = _trace_series(trace)
    csv_path = write_series_csv(
        joinpath(output_dir, "$(basename)_timeseries.csv"),
        "time_s",
        trace.time_s,
        series,
    )
    waveform_path = write_waveform_svg(
        joinpath(output_dir, "$(basename)_waveforms.svg"),
        trace.time_s,
        _preferred_waveforms(trace, series);
        title,
        y_label = "per-unit value",
    )
    deck_timing = deck_fixed_time_horizon_options(parsed)
    peak_voltage = maximum(abs, trace.voltage_pu; init = 0.0)
    peak_output = maximum(abs, trace.output_pu; init = 0.0)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        title,
        (
            case_id = id,
            input = portable_input_path(input_path),
            calculation,
            julia_only = true,
            deck_timestep_s = deck_timing.dt_s,
            deck_requested_duration_s = deck_timing.tmax_s,
            plotted_duration_s = isempty(trace.time_s) ? 0.0 : last(trace.time_s),
            recorded_samples = length(trace.time_s),
            nodes = length(trace.node_names),
            output_channels = length(trace.output_channel_names),
            maximum_absolute_voltage_pu = peak_voltage,
            maximum_absolute_output_pu = peak_output,
            interpretation,
        ),
    )
    @printf("Case: %s\n", String(id))
    @printf("Input: %s\n", input_path)
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", waveform_path)
    @printf("Summary: %s\n", summary_path)
    @printf("Recorded samples: %d\n", length(trace.time_s))
    return trace
end

function run_classic_transient_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    runtime_t_end_s::Real,
    initial_voltage_source::Symbol = :none,
    saturated_transformer_branch_runtime_enabled::Bool = false,
    coupled_lumped_sequence_history_enabled::Bool = false,
    args = ARGS,
)
    AIMORA.require_solver()
    output_dir = artifact_directory(args, joinpath(pwd(), "outputs"))
    input_path, parsed = _parsed_case(id)
    deck_timing = deck_fixed_time_horizon_options(parsed)
    dt_s = Float64(deck_timing.dt_s)
    t_end_s = Float64(runtime_t_end_s)
    dt_s > 0.0 || throw(ArgumentError("classic transient requires a positive deck timestep"))
    0.0 < t_end_s <= deck_timing.tmax_s ||
        throw(ArgumentError("display horizon must be within the deck horizon"))
    step_count = round(Int, t_end_s / dt_s)
    full_horizon = deck_fixed_step_horizon(parsed)
    trace = if step_count == full_horizon.step_count
        run_deck_emt(
            parsed;
            time_horizon = :deck,
            initial_voltage_source,
            saturated_transformer_branch_runtime_enabled,
            coupled_lumped_sequence_history_enabled,
            recorded_step_indices = _recorded_steps(step_count),
        )
    else
        run_deck_emt(
            parsed;
            dt_s,
            t_end_s = step_count * dt_s,
            initial_voltage_source,
            saturated_transformer_branch_runtime_enabled,
            coupled_lumped_sequence_history_enabled,
            recorded_step_indices = _recorded_steps(step_count),
        )
    end
    return _write_trace_artifacts(
        id,
        title,
        interpretation,
        input_path,
        parsed,
        trace,
        output_dir;
        calculation = "fixed-step EMT transient",
    )
end

function run_classic_universal_machine_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    args = ARGS,
)
    AIMORA.require_solver()
    output_dir = artifact_directory(args, joinpath(pwd(), "outputs"))
    input_path, parsed = _parsed_case(id)
    horizon = deck_fixed_step_horizon(parsed)
    trace = run_deck_emt(
        parsed;
        time_horizon = :deck,
        recorded_step_indices = _recorded_steps(horizon.step_count),
    )
    return _write_trace_artifacts(
        id,
        title,
        interpretation,
        input_path,
        parsed,
        trace,
        output_dir;
        calculation = "coupled universal-machine EMT horizon",
    )
end

function run_classic_synchronous_machine_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    runtime_t_end_s::Real,
    args = ARGS,
)
    AIMORA.require_solver()
    output_dir = artifact_directory(args, joinpath(pwd(), "outputs"))
    input_path, parsed = _parsed_case(id)
    deck_horizon = deck_fixed_step_horizon(parsed)
    dynamic_step_count = round(Int, Float64(runtime_t_end_s) / deck_horizon.dt_s)
    1 <= dynamic_step_count <= deck_horizon.step_count ||
        throw(ArgumentError("machine display horizon must be within the deck horizon"))
    machine = run_deck_synchronous_machine_horizon(
        parsed;
        dynamic_step_count,
        recorded_step_indices = _recorded_steps(dynamic_step_count),
    )
    isempty(machine.deferred_effects) ||
        error("synchronous-machine example has deferred effects: $(machine.deferred_effects)")
    return _write_trace_artifacts(
        id,
        title,
        interpretation,
        input_path,
        parsed,
        machine.trace,
        output_dir;
        calculation = "network-coupled synchronous-machine horizon",
    )
end

function run_classic_steady_state_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    args = ARGS,
)
    AIMORA.require_solver()
    output_dir = artifact_directory(args, joinpath(pwd(), "outputs"))
    input_path, parsed = _parsed_case(id)
    steady_state = deck_steady_state_voltage_phasors(parsed)
    indices = collect(eachindex(steady_state.node_names))
    phasors = steady_state.node_voltage_phasors
    csv_path = write_series_csv(
        joinpath(output_dir, "$(id)_phasors.csv"),
        "node_index",
        indices,
        [
            "voltage_real" => real.(phasors),
            "voltage_imaginary" => imag.(phasors),
            "voltage_magnitude" => abs.(phasors),
            "voltage_angle_deg" => rad2deg.(angle.(phasors)),
        ],
    )
    plot_path = write_waveform_svg(
        joinpath(output_dir, "$(id)_voltage_magnitudes.svg"),
        indices,
        ["voltage_magnitude" => abs.(phasors)];
        title,
        x_label = "node index",
        y_label = "voltage magnitude",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        title,
        (
            case_id = id,
            input = portable_input_path(input_path),
            calculation = "steady-state phasor network",
            julia_only = true,
            frequency_hz = steady_state.steady_state_frequency_hz,
            node_count = length(steady_state.node_names),
            source_count = steady_state.source_row_count,
            maximum_voltage_magnitude = maximum(abs, phasors),
            interpretation,
        ),
    )
    @printf("Case: %s\n", String(id))
    @printf("Input: %s\n", input_path)
    @printf("Phasors: %s\n", csv_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
    return steady_state
end

function run_classic_line_constants_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    args = ARGS,
)
    AIMORA.require_solver()
    output_dir = artifact_directory(args, joinpath(pwd(), "outputs"))
    input_path, parsed = _parsed_case(id)
    study = run_line_constants_study(parsed)
    study.physical_checks_passed ||
        error("line-constants physical checks did not pass")
    report_path = write_line_constants_report(
        joinpath(output_dir, "$(id)_report.txt"),
        study,
    )
    sequence_labels = String[]
    frequency_hz = Float64[]
    zc_magnitude_ohm = Float64[]
    resistance_ohm_per_mile = Float64[]
    reactance_ohm_per_mile = Float64[]
    for result in study.frequency_results, row in result.sequence_constants
        push!(sequence_labels, String(row.sequence))
        push!(frequency_hz, result.frequency_hz)
        push!(zc_magnitude_ohm, row.surge_impedance_magnitude_ohm)
        push!(resistance_ohm_per_mile, row.resistance_ohm_per_mile)
        push!(reactance_ohm_per_mile, row.reactance_ohm_per_mile)
    end
    csv_path = joinpath(output_dir, "$(id)_sequence_constants.csv")
    open(csv_path, "w") do io
        println(
            io,
            "frequency_hz,sequence,zc_magnitude_ohm,resistance_ohm_per_mile,reactance_ohm_per_mile",
        )
        for index in eachindex(sequence_labels)
            @printf(
                io,
                "%.12g,%s,%.12g,%.12g,%.12g\n",
                frequency_hz[index],
                sequence_labels[index],
                zc_magnitude_ohm[index],
                resistance_ohm_per_mile[index],
                reactance_ohm_per_mile[index],
            )
        end
    end
    plot_path = write_waveform_svg(
        joinpath(output_dir, "$(id)_sequence_impedance.svg"),
        collect(eachindex(zc_magnitude_ohm)),
        ["surge_impedance_magnitude_ohm" => zc_magnitude_ohm];
        title,
        x_label = "frequency/sequence row",
        y_label = "surge impedance magnitude (ohm)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        title,
        (
            case_id = id,
            input = portable_input_path(input_path),
            calculation = "overhead line constants",
            julia_only = true,
            conductor_count = length(study.physical_conductors),
            frequency_count = length(study.frequency_results),
            physical_checks_passed = study.physical_checks_passed,
            interpretation,
        ),
    )
    @printf("Case: %s\n", String(id))
    @printf("Input: %s\n", input_path)
    @printf("Report: %s\n", report_path)
    @printf("Sequence CSV: %s\n", abspath(csv_path))
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
    return study
end

end
