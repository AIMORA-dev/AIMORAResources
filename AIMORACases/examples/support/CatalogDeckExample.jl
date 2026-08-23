module CatalogDeckExample

using Printf

import AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using AIMORACases
using ..ExampleSupport

export run_catalog_deck_example

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

function _waveform_series(trace::DeckEMTTrace, all_series)
    if !isempty(trace.output_channel_names)
        node_count = length(trace.node_names)
        first_output = node_count + 1
        last_output = min(length(all_series), first_output + 5)
        return all_series[first_output:last_output]
    end
    return all_series[1:min(length(all_series), 6)]
end

function run_catalog_deck_example(
    id::Symbol;
    title::AbstractString,
    interpretation::AbstractString,
    args = ARGS,
)
    AIMORA.require_solver()
    input_path = AIMORACases.case_path(id)
    output_dir = artifact_directory(args, joinpath(dirname(input_path), "outputs"))
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    trace = run_deck_emt(parsed; time_horizon = :deck)
    all_series = _trace_series(trace)
    basename = replace(String(id), r"^emt_" => "")
    csv_path = write_series_csv(
        joinpath(output_dir, "$(basename)_timeseries.csv"),
        "time_s",
        trace.time_s,
        all_series,
    )
    waveform_path = write_waveform_svg(
        joinpath(output_dir, "$(basename)_waveforms.svg"),
        trace.time_s,
        _waveform_series(trace, all_series);
        title = title,
        y_label = "per-unit value",
    )
    peak_voltage = maximum(abs, trace.voltage_pu; init = 0.0)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        title,
        (
            case_id = id,
            input = portable_input_path(input_path),
            julia_only = true,
            timestep_s = trace.dt_s,
            duration_s = trace.t_end_s,
            samples = length(trace.time_s),
            nodes = length(trace.node_names),
            output_channels = length(trace.output_channel_names),
            maximum_absolute_voltage_pu = peak_voltage,
            interpretation = interpretation,
        ),
    )

    @printf("Case: %s\n", String(id))
    @printf("Input: %s\n", input_path)
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", waveform_path)
    @printf("Summary: %s\n", summary_path)
    @printf("Samples: %d at %.3f us\n", length(trace.time_s), trace.dt_s * 1e6)
    return trace
end

end
