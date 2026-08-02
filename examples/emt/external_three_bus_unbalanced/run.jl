#!/usr/bin/env julia

using Printf
using Statistics

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const DECK_PATH = joinpath(@__DIR__, "three_bus_unbalanced.deck")

rms(values) = sqrt(sum(abs2, values) / length(values))

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    parsed = parse_example_deck(DECK_PATH)
    assert_deck_valid!(parsed)
    trace = run_deck_emt(parsed; dt_s = 50e-6, t_end_s = 20e-3)
    selected_nodes = [
        :source_a, :source_b, :source_c,
        :primary_a, :primary_b, :primary_c,
        :load_a, :load_b, :load_c,
    ]
    series = Pair{String,Vector{Float64}}[
        "$(node)_v_pu" => vec(trace.voltage_pu[trace.node_map[node], :])
        for node in selected_nodes
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "three_bus_unbalanced.csv"),
        "time_s",
        trace.time_s,
        series,
    )
    load_series = series[7:9]
    svg_path = write_waveform_svg(
        joinpath(output_dir, "load_bus_waveforms.svg"),
        trace.time_s,
        load_series;
        title = "Adapted Three-Bus Unbalanced Load Voltages",
        y_label = "voltage (pu)",
    )
    va, vb, vc = last.(load_series)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "External Three-Bus Unbalanced Feeder Adaptation",
        (
            upstream_revision = "87dc18b00964d7fb5de8f48da40043968f2667b0",
            frequency_hz = 50.0,
            phase_a_rms_pu = rms(va),
            phase_b_rms_pu = rms(vb),
            phase_c_rms_pu = rms(vc),
            maximum_phase_sum_pu = maximum(abs, va .+ vb .+ vc),
            electrically_equivalent_to_upstream = false,
            julia_only = true,
        ),
    )
    @printf("Input: %s\n", abspath(DECK_PATH))
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", svg_path)
    @printf("Summary: %s\n", summary_path)
end

main()
