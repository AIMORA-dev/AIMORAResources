module MultiDeckGallery

using Printf

import AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using ..ExampleSupport

export run_deck_gallery

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

function _waveform_series(trace::DeckEMTTrace, series)
    if !isempty(trace.output_channel_names)
        first_output = length(trace.node_names) + 1
        return series[first_output:min(length(series), first_output + 5)]
    end
    return series[1:min(length(series), 6)]
end

function run_deck_gallery(
    cases;
    gallery_title::AbstractString,
    interpretation::AbstractString,
    args = ARGS,
)
    isempty(cases) && throw(ArgumentError("a deck gallery requires at least one case"))
    AIMORA.require_solver()
    default_output = joinpath(dirname(abspath(first(cases).path)), "outputs")
    output_dir = artifact_directory(args, default_output)
    results = NamedTuple[]

    for case in cases
        input_path = abspath(case.path)
        parsed = parse_example_deck(input_path)
        assert_deck_valid!(parsed)
        trace = run_deck_emt(parsed; time_horizon = :deck)
        series = _trace_series(trace)
        isempty(series) && error("$(case.name) produced no plottable channels")
        csv_path = write_series_csv(
            joinpath(output_dir, "$(case.name)_timeseries.csv"),
            "time_s",
            trace.time_s,
            series,
        )
        waveform_path = write_waveform_svg(
            joinpath(output_dir, "$(case.name)_waveforms.svg"),
            trace.time_s,
            _waveform_series(trace, series);
            title = case.title,
            y_label = "per-unit value",
        )
        push!(results, (;
            name = case.name,
            input_path,
            trace,
            csv_path,
            waveform_path,
            maximum_voltage_pu = maximum(abs, trace.voltage_pu; init = 0.0),
            maximum_output_pu = maximum(abs, trace.output_pu; init = 0.0),
        ))
    end

    metrics_path = joinpath(output_dir, "gallery_metrics.csv")
    open(metrics_path, "w") do io
        println(io, "case,samples,timestep_s,duration_s,nodes,output_channels,maximum_voltage_pu,maximum_output_pu")
        for result in results
            trace = result.trace
            @printf(
                io,
                "%s,%d,%.12g,%.12g,%d,%d,%.12g,%.12g\n",
                String(result.name),
                length(trace.time_s),
                trace.dt_s,
                trace.t_end_s,
                length(trace.node_names),
                length(trace.output_channel_names),
                result.maximum_voltage_pu,
                result.maximum_output_pu,
            )
        end
    end
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        gallery_title,
        (
            julia_only = true,
            case_count = length(results),
            cases = join((String(result.name) for result in results), ", "),
            all_values_finite = all(result ->
                all(isfinite, result.trace.voltage_pu) &&
                all(isfinite, result.trace.output_pu), results),
            interpretation = interpretation,
        ),
    )

    @printf("Gallery: %s\n", gallery_title)
    @printf("Cases: %d\n", length(results))
    @printf("Metrics: %s\n", abspath(metrics_path))
    @printf("Summary: %s\n", summary_path)
    return results
end

end
