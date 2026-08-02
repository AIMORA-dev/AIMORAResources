#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const DT_S = 50e-6
const DECK = [
    "source grid source 1.0e9 1.0 60.0 0.0 0.0",
    "bergeron_line line source load 2.0 $(2.0 * DT_S) $(DT_S) 0.9",
    "resistor load_r load 0 2.0",
    "time_switch shunt load 0 $(12.0 * DT_S) $(18.0 * DT_S) false 20.0 0.0",
]

function workspace(parsed, duration_s)
    return EMTStudyWorkspace(
        prepare_emt_study(parsed; dt_s = DT_S, t_end_s = duration_s),
    )
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    parsed = parse_deck_lines(DECK; source = "checkpoint restart example")
    assert_deck_valid!(parsed)

    full_workspace = workspace(parsed, 20.0 * DT_S)
    full_trace = evaluate_emt_study!(full_workspace)

    split_workspace = workspace(parsed, 10.0 * DT_S)
    evaluate_emt_study!(split_workspace)
    checkpoint_path = joinpath(output_dir, "checkpoint.aimora")
    continued_path = joinpath(output_dir, "continued.aimora")
    report_path = joinpath(output_dir, "restart_report.json")
    write_emt_checkpoint(checkpoint_path, split_workspace)
    request = parse_emt_restart_request([
        "START AGAIN, CHECKPOINT=\"$(checkpoint_path)\"",
        lpad("9999", 8),
    ])
    continuation = restart_emt_checkpoint(
        request;
        additional_time_s = 10.0 * DT_S,
        report_path,
        continued_checkpoint_path = continued_path,
    )
    restarted = continuation.run.trace
    load_index = full_trace.node_map[:load]
    full_voltage = vec(full_trace.voltage_pu[load_index, :])
    restarted_voltage = vec(restarted.voltage_pu[load_index, :])
    error = restarted_voltage .- full_voltage
    csv_path = write_series_csv(
        joinpath(output_dir, "restart_comparison.csv"),
        "time_s",
        full_trace.time_s,
        [
            "uninterrupted_load_v_pu" => full_voltage,
            "restarted_load_v_pu" => restarted_voltage,
            "difference_pu" => error,
        ],
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "restart_comparison.svg"),
        full_trace.time_s,
        [
            "uninterrupted" => full_voltage,
            "checkpoint_restart" => restarted_voltage,
        ];
        title = "Checkpoint/Restart Continuity",
        y_label = "load voltage (pu)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Checkpoint and Restart Continuation",
        (
            split_time_s = 10.0 * DT_S,
            final_time_s = 20.0 * DT_S,
            maximum_waveform_error_pu = maximum(abs, error),
            checkpoint_state_error = continuation.run.checkpoint_state_error,
            final_kcl_error = continuation.run.final_kcl_error,
            julia_only = true,
        ),
    )
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", svg_path)
    @printf("Checkpoint: %s\n", abspath(checkpoint_path))
    @printf("Summary: %s\n", summary_path)
end

main()
