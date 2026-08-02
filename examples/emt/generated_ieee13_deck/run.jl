#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const DECK_PATH = joinpath(@__DIR__, "ieee13_minimum_core.deck")

function write_summary(path::AbstractString, summary::DeckModelSummary)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "{")
        @printf(io, "  \"source\": \"%s\",\n", summary.source)
        @printf(io, "  \"node_count\": %d,\n", summary.node_count)
        @printf(io, "  \"element_count\": %d,\n", summary.element_count)
        println(io, "  \"node_names\": [")
        for (index, name) in enumerate(summary.node_names)
            suffix = index == length(summary.node_names) ? "" : ","
            @printf(io, "    \"%s\"%s\n", String(name), suffix)
        end
        println(io, "  ],")
        println(io, "  \"element_names\": [")
        for (index, name) in enumerate(summary.element_names)
            suffix = index == length(summary.element_names) ? "" : ","
            @printf(io, "    \"%s\"%s\n", String(name), suffix)
        end
        println(io, "  ]")
        println(io, "}")
    end
    return path
end

function write_table_csv(path::AbstractString, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "id,index,kind,source")
        for row in rows
            kind = get(row, :kind, "")
            @printf(io, "%s,%d,%s,%s\n", String(row[:id]), row[:index], String(kind), row[:source])
        end
    end
    return path
end

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    parsed = parse_example_deck(DECK_PATH)
    assert_deck_valid!(parsed)
    summary = deck_model_summary(parsed)
    tables = deck_asset_tables(parsed)
    trace = run_deck_emt(parsed; dt_s = 20e-6, t_end_s = 100e-6)

    summary_path = write_summary(joinpath(output_dir, "ieee13_parser_summary.json"), summary)
    bus_path = write_table_csv(joinpath(output_dir, "ieee13_buses.csv"), tables[:buses])
    element_path = write_table_csv(joinpath(output_dir, "ieee13_elements.csv"), tables[:emt_elements])
    waveform_nodes = Symbol.(("650", "632", "675"))
    series = Pair{String,Vector{Float64}}[
        string(node) => vec(trace.voltage_pu[trace.node_map[node], :])
        for node in waveform_nodes
    ]
    timeseries_path = write_series_csv(
        joinpath(output_dir, "ieee13_timeseries.csv"),
        "time_s",
        trace.time_s,
        series,
    )
    waveform_path = write_waveform_svg(
        joinpath(output_dir, "ieee13_waveforms.svg"),
        trace.time_s,
        series;
        title = "IEEE 13-Node-Style Feeder Voltages",
        y_label = "voltage (pu)",
    )

    @printf("Deck: %s\n", abspath(DECK_PATH))
    @printf("Summary: %s\n", abspath(summary_path))
    @printf("Buses: %s\n", abspath(bus_path))
    @printf("Elements: %s\n", abspath(element_path))
    @printf("Timeseries: %s\n", timeseries_path)
    @printf("Waveform: %s\n", waveform_path)
    @printf("Nodes: %d\n", summary.node_count)
    @printf("Elements: %d\n", summary.element_count)
    @printf("First/last node: %s / %s\n", String(first(summary.node_names)), String(last(summary.node_names)))
end

main()
