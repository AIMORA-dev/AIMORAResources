#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    input_path = joinpath(@__DIR__, "mixed_frequency_subnetworks.deck")
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    phasors = deck_steady_state_voltage_phasors(parsed)
    trace = run_deck_emt(
        parsed;
        time_horizon = :deck,
        initial_voltage_source = :steady_state,
    )
    waveform_series = [
        "$(trace.node_names[index])_voltage" => vec(trace.voltage_pu[index, :])
        for index in eachindex(trace.node_names)
    ]
    waveform_csv = write_series_csv(
        joinpath(output_dir, "mixed_frequency_waveforms.csv"),
        "time_s",
        trace.time_s,
        waveform_series,
    )
    waveform_svg = write_waveform_svg(
        joinpath(output_dir, "mixed_frequency_waveforms.svg"),
        trace.time_s,
        waveform_series;
        title = "Disconnected 50 Hz and 60 Hz EMT Subnetworks",
        y_label = "voltage (input peak units)",
    )
    phasor_path = joinpath(output_dir, "phasors.csv")
    open(phasor_path, "w") do io
        println(io, "node,frequency_hz,voltage_real,voltage_imaginary,voltage_magnitude,voltage_angle_deg")
        for index in eachindex(phasors.node_names)
            voltage = phasors.node_voltage_phasors[index]
            @printf(
                io,
                "%s,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                String(phasors.node_names[index]),
                phasors.node_steady_state_frequencies_hz[index],
                real(voltage),
                imag(voltage),
                abs(voltage),
                rad2deg(angle(voltage)),
            )
        end
    end
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Mixed-Frequency Steady-State Subnetworks",
        (
            julia_only = true,
            subnetwork_count = phasors.steady_state_frequency_subnetwork_count,
            frequencies_hz =
                join(unique(phasors.node_steady_state_frequencies_hz), ", "),
            samples = length(trace.time_s),
            all_results_finite =
                all(isfinite, trace.voltage_pu) &&
                all(isfinite, real.(phasors.node_voltage_phasors)) &&
                all(isfinite, imag.(phasors.node_voltage_phasors)),
            interpretation =
                "The two islands preserve independent 50 Hz and 60 Hz phasor initialization and time-domain waveforms.",
        ),
    )
    @printf("Waveform CSV: %s\n", waveform_csv)
    @printf("Waveform SVG: %s\n", waveform_svg)
    @printf("Phasors: %s\n", abspath(phasor_path))
    @printf("Summary: %s\n", summary_path)
end

main()
