#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.EMTStudy
using .ExampleSupport

const FREQUENCY_HZ = 50.0
const DT_S = 50e-6

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    phase_b = -2.0 * pi / 3.0
    phase_c = 2.0 * pi / 3.0
    deck = [
        "source source_a phase_a 1.0e9 1.0 $(FREQUENCY_HZ) 0.0 0.0",
        "source source_b phase_b 1.0e9 1.0 $(FREQUENCY_HZ) $(phase_b) 0.0",
        "source source_c phase_c 1.0e9 1.0 $(FREQUENCY_HZ) $(phase_c) 0.0",
        "resistor load_a phase_a 0 1.0",
        "resistor load_b phase_b 0 1.0",
        "resistor load_c phase_c 0 1.0",
    ]
    trace = run_deck_emt(
        deck;
        dt_s = DT_S,
        t_end_s = 1.0 / FREQUENCY_HZ,
        source = "balanced three-phase sine example",
    )
    va = vec(trace.voltage_pu[trace.node_map[:phase_a], :])
    vb = vec(trace.voltage_pu[trace.node_map[:phase_b], :])
    vc = vec(trace.voltage_pu[trace.node_map[:phase_c], :])
    vab = va .- vb
    vbc = vb .- vc
    vca = vc .- va
    phase_series = [
        "phase_a_v_pu" => va,
        "phase_b_v_pu" => vb,
        "phase_c_v_pu" => vc,
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "balanced_three_phase.csv"),
        "time_s",
        trace.time_s,
        [
            phase_series...,
            "v_ab_pu" => vab,
            "v_bc_pu" => vbc,
            "v_ca_pu" => vca,
        ],
    )
    phase_plot = write_waveform_svg(
        joinpath(output_dir, "phase_voltages.svg"),
        trace.time_s,
        phase_series;
        title = "Balanced Three-Phase 50 Hz Source",
        y_label = "phase voltage (pu)",
    )
    line_plot = write_waveform_svg(
        joinpath(output_dir, "line_to_line_voltages.svg"),
        trace.time_s,
        ["v_ab_pu" => vab, "v_bc_pu" => vbc, "v_ca_pu" => vca];
        title = "Balanced Line-to-Line Voltages",
        y_label = "line voltage (pu)",
    )
    balance_error = maximum(abs, va .+ vb .+ vc)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Balanced Three-Phase Sine Source",
        (
            frequency_hz = FREQUENCY_HZ,
            phase_displacement_deg = 120.0,
            maximum_phase_sum_error_pu = balance_error,
            expected_line_to_phase_peak_ratio = sqrt(3.0),
            measured_line_to_phase_peak_ratio =
                maximum(abs, vab) / maximum(abs, va),
        ),
    )

    @printf("CSV: %s\n", csv_path)
    @printf("Phase waveform: %s\n", phase_plot)
    @printf("Line waveform: %s\n", line_plot)
    @printf("Summary: %s\n", summary_path)
end

main()
