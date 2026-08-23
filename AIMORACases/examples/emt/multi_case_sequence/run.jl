#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const SEQUENCE_LINES = [
    "BEGIN NEW DATA CASE",
    "source first_source first_source_bus 1.0e12 0.0 0.0 0.0 1.0",
    "resistor first_feeder first_source_bus first_load_bus 2.0",
    "resistor first_load first_load_bus 0 2.0",
    "END NEW DATA CASE",
    "BEGIN NEW DATA CASE",
    "source discarded_source discarded_bus 1.0e12 0.0 0.0 0.0 99.0",
    "ABORT DATA CASE",
    "THIS CARD IS DISCARDED BY THE CASE LIFECYCLE",
    "BEGIN NEW DATA CASE",
    "source second_source second_source_bus 1.0e12 0.0 0.0 0.0 2.0",
    "resistor second_feeder second_source_bus second_load_bus 2.0",
    "resistor second_load second_load_bus 0 2.0",
    "BLANK CARD TERMINATING THE CASE",
]

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    sequence = parse_deck_case_sequence(
        SEQUENCE_LINES;
        source = "multi-case sequence example",
    )
    run = run_deck_case_sequence_emt(
        sequence;
        dt_s = 50e-6,
        t_end_s = 0.5e-3,
    )
    first_trace = run.cases[1].trace
    second_trace = run.cases[2].trace
    first_voltage =
        vec(first_trace.voltage_pu[first_trace.node_map[:first_load_bus], :])
    second_voltage =
        vec(second_trace.voltage_pu[second_trace.node_map[:second_load_bus], :])
    series = [
        "case_1_load_v_pu" => first_voltage,
        "case_2_load_v_pu" => second_voltage,
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "case_sequence.csv"),
        "time_s",
        first_trace.time_s,
        series,
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "case_sequence.svg"),
        first_trace.time_s,
        series;
        title = "Isolated Multi-Case EMT Sequence",
        y_label = "load voltage (pu)",
    )
    sequence_summary = write_deck_case_sequence_summary(
        joinpath(output_dir, "case_sequence_summary.toml"),
        run,
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Multi-Case Study Sequence",
        (
            executed_cases = length(run.cases),
            aborted_cases = run.aborted_case_count,
            discarded_cards = run.discarded_card_count,
            run_terminated = run.run_terminated,
            first_final_voltage_pu = last(first_voltage),
            second_final_voltage_pu = last(second_voltage),
            julia_only = true,
        ),
    )
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", svg_path)
    @printf("Sequence summary: %s\n", sequence_summary)
    @printf("Summary: %s\n", summary_path)
end

main()
