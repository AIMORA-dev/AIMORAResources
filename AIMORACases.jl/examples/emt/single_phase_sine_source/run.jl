#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.EMTStudy
using .ExampleSupport

const FREQUENCY_HZ = 60.0
const SAMPLES_PER_CYCLE = 360
const DT_S = 1.0 / (FREQUENCY_HZ * SAMPLES_PER_CYCLE)

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    deck = [
        "source grid phase_a 1.0e9 1.0 $(FREQUENCY_HZ) 0.0 0.0",
        "resistor load phase_a 0 1.0",
    ]
    trace = run_deck_emt(
        deck;
        dt_s = DT_S,
        t_end_s = 1.0 / FREQUENCY_HZ,
        source = "single-phase sine source example",
    )
    voltage = vec(trace.voltage_pu[trace.node_map[:phase_a], :])
    csv_path = write_series_csv(
        joinpath(output_dir, "single_phase_sine.csv"),
        "time_s",
        trace.time_s,
        ["phase_a_voltage_pu" => voltage],
    )
    waveform_path = write_waveform_svg(
        joinpath(output_dir, "single_phase_sine.svg"),
        trace.time_s,
        ["phase_a_voltage_pu" => voltage];
        title = "Single-Phase 60 Hz Sine Source",
        y_label = "voltage (pu)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Single-Phase Sine Source",
        (
            equation = "v(t) = sin(2π × 60 × t) pu",
            frequency_hz = FREQUENCY_HZ,
            timestep_s = DT_S,
            samples = length(trace.time_s),
            measured_peak_pu = maximum(abs, voltage),
            measured_final_pu = last(voltage),
        ),
    )

    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", waveform_path)
    @printf("Summary: %s\n", summary_path)
end

main()
