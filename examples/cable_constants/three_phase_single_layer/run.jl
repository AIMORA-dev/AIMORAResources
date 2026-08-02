#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.CableConstantsStudy
using AIMORA.DeckParser
using AIMORA.ReportArtifacts
using AIMORACases
using .ExampleSupport

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    input_path = case_path(:cable_constants_three_phase_single_layer)
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    study = run_cable_constants_study(parsed)
    study.physical_checks_passed ||
        error("cable-constants physical checks did not pass")

    report_path = write_cable_constants_report_text(
        joinpath(output_dir, "cable_constants_report.txt"),
        study,
    )
    frequency_hz = [state.frequency_hz for state in study.frequency_states]
    modal_z = [
        abs(first(state.modal_characteristic_impedance_ohm))
        for state in study.frequency_states
    ]
    modal_velocity = [
        first(state.modal_velocity_m_per_s)
        for state in study.frequency_states
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "cable_frequency_scan.csv"),
        "frequency_hz",
        frequency_hz,
        [
            "mode1_zc_magnitude_ohm" => modal_z,
            "mode1_velocity_m_per_s" => modal_velocity,
        ],
    )
    plot_path = write_waveform_svg(
        joinpath(output_dir, "cable_characteristic_impedance.svg"),
        frequency_hz,
        ["mode1_zc_magnitude_ohm" => modal_z];
        title = "Cable Mode-1 Characteristic Impedance",
        x_label = "frequency (Hz)",
        y_label = "magnitude (ohm)",
    )
    first_state = first(study.frequency_states)
    matrix_path = write_matrix_csv(
        joinpath(output_dir, "series_impedance_60hz.csv"),
        first_state.series_impedance_matrix_ohm_per_m;
        row_prefix = "conductor",
        column_prefix = "conductor",
    )

    @printf("Input: %s\n", input_path)
    @printf("Report: %s\n", report_path)
    @printf("Frequency scan: %s\n", csv_path)
    @printf("60 Hz matrix: %s\n", matrix_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Frequencies: %d\n", length(frequency_hz))
end

main()
