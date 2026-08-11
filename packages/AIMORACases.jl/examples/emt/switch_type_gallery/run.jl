#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const SWITCH_CASES = (
    (name = :current_zero, file = "current_zero.deck"),
    (name = :type76, file = "type76.deck"),
)

function trace_series(trace)
    series = Pair{String,Vector{Float64}}[]
    for (index, name) in enumerate(trace.node_names)
        push!(series, "$(name)_voltage" => vec(trace.voltage_pu[index, :]))
    end
    for (index, name) in enumerate(trace.output_channel_names)
        push!(series, "$(name)" => vec(trace.output_pu[index, :]))
    end
    return series
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    runs = NamedTuple[]
    combined_series = Pair{String,Vector{Float64}}[]
    combined_time = nothing
    for case in SWITCH_CASES
        parsed = parse_example_deck(joinpath(@__DIR__, case.file))
        assert_deck_valid!(parsed)
        trace = run_deck_emt(parsed; time_horizon = :deck)
        series = trace_series(trace)
        write_series_csv(
            joinpath(output_dir, "$(case.name)_timeseries.csv"),
            "time_s",
            trace.time_s,
            series,
        )
        write_waveform_svg(
            joinpath(output_dir, "$(case.name)_waveforms.svg"),
            trace.time_s,
            series[1:min(length(series), 6)];
            title = "$(replace(titlecase(String(case.name)), "_" => " ")) Switch",
            y_label = "electrical value",
        )
        push!(runs, (
            name = case.name,
            trace,
            peak_voltage = maximum(abs, trace.voltage_pu),
            peak_output = maximum(abs, trace.output_pu),
        ))
        if combined_time === nothing
            combined_time = trace.time_s
            push!(combined_series, "$(case.name)_representative" => last(series).second)
        end
    end
    metrics_path = joinpath(output_dir, "switch_metrics.csv")
    open(metrics_path, "w") do io
        println(io, "case,samples,timestep_s,duration_s,maximum_voltage,maximum_output")
        for row in runs
            @printf(
                io,
                "%s,%d,%.12g,%.12g,%.12g,%.12g\n",
                String(row.name),
                length(row.trace.time_s),
                row.trace.dt_s,
                row.trace.t_end_s,
                row.peak_voltage,
                row.peak_output,
            )
        end
    end
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Specialized Switch-Type Gallery",
        (
            julia_only = true,
            case_count = length(runs),
            all_results_finite = all(
                row ->
                    all(isfinite, row.trace.voltage_pu) &&
                    all(isfinite, row.trace.output_pu),
                runs,
            ),
            interpretation =
                "Current extinction and timed-resistance state changes produce distinct finite switch voltage/current responses.",
        ),
    )
    @printf("Metrics: %s\n", abspath(metrics_path))
    @printf("Summary: %s\n", summary_path)
end

main()
