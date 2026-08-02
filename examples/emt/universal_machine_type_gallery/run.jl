#!/usr/bin/env julia

using LinearAlgebra
using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using AIMORA.Machines
using .ExampleSupport

const DT_S = 10.0e-6
const FREQUENCY_HZ = 60.0
const STEP_COUNT = 600
const VOLTAGE_PEAK_V = 0.1
const EXPECTED_DECK_FILES = (
    "c307_automatic_direct_machine_type10.deck",
    "c307_automatic_direct_machine_type11.deck",
    "c307_automatic_direct_machine_type12.deck",
    "c307_automatic_direct_machine_type9.deck",
    "detailed_synchronous_machine_universal_section.deck",
    "synchronous_machine_saturated_delta_fleet.deck",
    "universal_machine_direct_coupled_fleet.deck",
    "universal_machine_direct_electromechanical_fleet.deck",
    "universal_machine_direct_fleet.deck",
    "universal_machine_direct_tacs_fleet.deck",
    "universal_machine_type1.deck",
    "universal_machine_type10.deck",
    "universal_machine_type11.deck",
    "universal_machine_type12.deck",
    "universal_machine_type2.deck",
    "universal_machine_type3.deck",
    "universal_machine_type3_manual.deck",
    "universal_machine_type3_normalized.deck",
    "universal_machine_type3_normalized_predicted_current.deck",
    "universal_machine_type3_predicted_current.deck",
    "universal_machine_type3_remanent.deck",
    "universal_machine_type4.deck",
    "universal_machine_type5.deck",
    "universal_machine_type6.deck",
    "universal_machine_type7.deck",
    "universal_machine_type8.deck",
    "universal_machine_type8_automatic.deck",
    "universal_machine_type9.deck",
    "universal_machine_type9_series_leakage.deck",
)

function axis_counts(machine_type::Int)
    machine_type in (6, 8) && return (1, 0)
    machine_type in (9, 10, 11, 12) && return (2, 0)
    return (1, 1)
end

function coil_count(machine_type::Int)
    d_axis_count, q_axis_count = axis_counts(machine_type)
    return 3 + d_axis_count + q_axis_count + (machine_type == 4 ? 1 : 0)
end

function terminal_voltage(machine_type::Int, time_s::Float64)
    angle = 2.0 * pi * FREQUENCY_HZ * time_s
    machine_type in (6, 7, 8, 9, 10, 11, 12) &&
        return [VOLTAGE_PEAK_V * sin(angle), 0.0, 0.0]
    machine_type in (2, 5) &&
        return [0.0, VOLTAGE_PEAK_V * sin(angle), VOLTAGE_PEAK_V * cos(angle)]
    return VOLTAGE_PEAK_V .* [
        sin(angle),
        sin(angle - 2.0 * pi / 3.0),
        sin(angle + 2.0 * pi / 3.0),
    ]
end

function simulate_machine_type(machine_type::Int, time_s::Vector{Float64})
    d_axis_count, q_axis_count = axis_counts(machine_type)
    count = coil_count(machine_type)
    synchronous_speed = machine_type in (1, 2) ? 2.0 * pi * FREQUENCY_HZ : 0.0
    imposed_speed = machine_type in (1, 2) ? synchronous_speed : 1.0
    parameters = InductionMachineParameters(
        fill(1.0, count),
        fill(0.01, count);
        time_step_s = DT_S,
        d_axis_unsaturated_inductance = 0.05,
        q_axis_unsaturated_inductance = 0.05,
        pole_pair_count = 2,
        d_axis_coil_count = d_axis_count,
        q_axis_coil_count = q_axis_count,
        synchronous_electrical_speed_rad_s = synchronous_speed,
        speed_tolerance_rad_s = 1.0e-6,
        machine_type,
        power_leakage_owned_by_network = false,
    )
    state = InductionMachineState(
        zeros(count),
        zeros(count);
        mechanical_speed_rad_s = imposed_speed,
        mechanical_angle_rad = 0.0,
    )
    current_rms = zeros(length(time_s))
    torque = zeros(length(time_s))
    speed = zeros(length(time_s))
    for index in eachindex(time_s)
        result = coupled_dq_machine_step!(
            state,
            parameters;
            power_terminal_voltages = terminal_voltage(machine_type, time_s[index]),
            rotor_thevenin_matrix = Matrix{Float64}(I, 3, 3),
            mechanical_speed_thevenin_rad_s = imposed_speed,
            generated_torque_impedance = 0.0,
            stator_terminal_voltages = zeros(count - 3),
            stator_thevenin_matrix = zeros(count - 3, count - 3),
            initial_step = index == firstindex(time_s),
        )
        current_rms[index] =
            sqrt(sum(abs2, result.current_values) / length(result.current_values))
        torque[index] = result.generated_torque
        speed[index] = result.mechanical_speed_rad_s
    end
    all(isfinite, current_rms) || error("type-$machine_type current is non-finite")
    all(isfinite, torque) || error("type-$machine_type torque is non-finite")
    all(isfinite, speed) || error("type-$machine_type speed is non-finite")
    return (; machine_type, count, current_rms, torque, speed)
end

function trace_series(trace)
    series = Pair{String,Vector{Float64}}[]
    for (index, name) in enumerate(trace.node_names)
        push!(series, "node_$(name)_voltage" => vec(trace.voltage_pu[index, :]))
    end
    for (index, name) in enumerate(trace.output_channel_names)
        push!(series, String(name) => vec(trace.output_pu[index, :]))
    end
    return series
end

function waveform_series(series)
    usable = filter(series) do item
        values = last(item)
        all(isfinite, values) && maximum(abs, values; init = 0.0) < 1.0e18
    end
    predicates = (
        label -> occursin("phase_", label) && occursin("current", label),
        label -> occursin("current", label),
        label -> occursin("torque", label),
        label -> occursin("speed", label),
        label -> startswith(label, "output_fixed_"),
        label -> startswith(label, "node_"),
        _ -> true,
    )
    for predicate in predicates
        candidates = filter(item -> predicate(lowercase(first(item))), usable)
        isempty(candidates) || return candidates[1:min(6, length(candidates))]
    end
    error("machine deck produced no finite plottable series")
end

function run_machine_deck(input_path::AbstractString)
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    filename = basename(input_path)
    if filename == "detailed_synchronous_machine_universal_section.deck"
        horizon = run_deck_synchronous_machine_horizon(parsed)
        complete = horizon.complete_machine_control_coupling &&
                   isempty(horizon.deferred_effects)
        return (;
            runner = :synchronous_machine,
            trace = horizon.trace,
            complete,
        )
    elseif filename == "synchronous_machine_saturated_delta_fleet.deck"
        horizon = run_deck_synchronous_machine_fleet_horizon(parsed)
        complete = horizon.complete_machine_network_coupling &&
                   horizon.complete_machine_control_coupling &&
                   isempty(horizon.deferred_effects)
        return (;
            runner = :synchronous_machine_fleet,
            trace = horizon.trace,
            complete,
        )
    end
    return (;
        runner = :universal_machine_emt,
        trace = run_deck_emt(parsed; time_horizon = :deck),
        complete = true,
    )
end

function write_equation_family_baseline(output_dir::AbstractString)
    time_s = collect(0:STEP_COUNT) .* DT_S
    runs = [simulate_machine_type(machine_type, time_s) for machine_type in 1:12]
    series = [
        "type_$(run.machine_type)_current_rms_A" => run.current_rms
        for run in runs
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "machine_type_current_rms.csv"),
        "time_s",
        time_s,
        series,
    )
    plot_path = write_waveform_svg(
        joinpath(output_dir, "machine_type_current_rms.svg"),
        time_s,
        series;
        title = "Universal-Machine Types 1–12: Coil-Current Response",
        y_label = "RMS-like coil current (A)",
    )
    metrics_path = joinpath(output_dir, "machine_type_metrics.csv")
    open(metrics_path, "w") do io
        println(io, "machine_type,coil_count,peak_current_rms_A,peak_torque_Nm,final_speed_rad_s")
        for run in runs
            @printf(
                io,
                "%d,%d,%.12g,%.12g,%.12g\n",
                run.machine_type,
                run.count,
                maximum(abs, run.current_rms),
                maximum(abs, run.torque),
                last(run.speed),
            )
        end
    end
    return (; runs, csv_path, plot_path, metrics_path)
end

function write_deck_gallery(output_dir::AbstractString)
    deck_dir = joinpath(@__DIR__, "decks")
    actual_files = Tuple(sort(filter(
        filename -> endswith(filename, ".deck"),
        readdir(deck_dir),
    )))
    actual_files == EXPECTED_DECK_FILES || error(
        "machine deck inventory changed: expected $(length(EXPECTED_DECK_FILES)), " *
        "found $(length(actual_files))",
    )

    results = NamedTuple[]
    for filename in EXPECTED_DECK_FILES
        stem = first(splitext(filename))
        input_path = joinpath(deck_dir, filename)
        execution = run_machine_deck(input_path)
        trace = execution.trace
        all(isfinite, trace.time_s) || error("$filename produced non-finite times")
        all(isfinite, trace.voltage_pu) || error("$filename produced non-finite voltages")
        all(isfinite, trace.output_pu) || error("$filename produced non-finite outputs")
        execution.complete || error("$filename reported an incomplete machine path")

        series = trace_series(trace)
        selected = waveform_series(series)
        write_series_csv(
            joinpath(output_dir, "$(stem)_timeseries.csv"),
            "time_s",
            trace.time_s,
            series,
        )
        write_waveform_svg(
            joinpath(output_dir, "$(stem)_waveforms.svg"),
            trace.time_s,
            selected;
            title = titlecase(replace(stem, '_' => ' ')),
            y_label = "machine response (units in legend)",
        )
        push!(results, (;
            filename,
            execution.runner,
            samples = length(trace.time_s),
            timestep_s = trace.dt_s,
            duration_s = trace.t_end_s,
            nodes = length(trace.node_names),
            output_channels = length(trace.output_channel_names),
            plotted_channels = join(first.(selected), ";"),
            maximum_abs_voltage = maximum(abs, trace.voltage_pu; init = 0.0),
            maximum_abs_plotted_response = maximum(
                (maximum(abs, last(item); init = 0.0) for item in selected);
                init = 0.0,
            ),
        ))
    end

    metrics_path = joinpath(output_dir, "deck_metrics.csv")
    open(metrics_path, "w") do io
        println(io, "case,input,runner,samples,timestep_s,duration_s,nodes,output_channels,maximum_abs_voltage,maximum_abs_plotted_response,plotted_channels")
        for result in results
            @printf(
                io,
                "%s,%s,%s,%d,%.12g,%.12g,%d,%d,%.12g,%.12g,%s\n",
                first(splitext(result.filename)),
                result.filename,
                String(result.runner),
                result.samples,
                result.timestep_s,
                result.duration_s,
                result.nodes,
                result.output_channels,
                result.maximum_abs_voltage,
                result.maximum_abs_plotted_response,
                result.plotted_channels,
            )
        end
    end
    return (; results, metrics_path)
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    baseline = write_equation_family_baseline(output_dir)
    gallery = write_deck_gallery(output_dir)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Universal and Detailed Machine Gallery",
        (
            julia_only = true,
            equation_family_baseline_types = "1:12",
            canonical_deck_count = length(gallery.results),
            universal_machine_emt_decks = count(
                result -> result.runner == :universal_machine_emt,
                gallery.results,
            ),
            detailed_synchronous_machine_decks = count(
                result -> result.runner != :universal_machine_emt,
                gallery.results,
            ),
            all_results_finite = true,
            interpretation =
                "All 29 public validation-derived machine decks execute through their production Julia timestep owners; the separate controlled baseline compares types 1–12 under one common excitation.",
        ),
    )
    @printf("Baseline CSV: %s\n", baseline.csv_path)
    @printf("Baseline waveform: %s\n", baseline.plot_path)
    @printf("Baseline metrics: %s\n", abspath(baseline.metrics_path))
    @printf("Decks executed: %d\n", length(gallery.results))
    @printf("Deck metrics: %s\n", abspath(gallery.metrics_path))
    @printf("Summary: %s\n", summary_path)
end

main()
