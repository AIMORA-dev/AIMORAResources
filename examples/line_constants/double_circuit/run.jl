#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.LineConstantsStudy
using AIMORACases
using .ExampleSupport

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    input_path = case_path(:line_constants_double_circuit)
    parsed = parse_example_deck(input_path)
    assert_deck_valid!(parsed)
    study = run_line_constants_study(parsed)
    study.physical_checks_passed ||
        error("line-constants physical checks did not pass")
    report_path = write_line_constants_report(
        joinpath(output_dir, "line_constants_report.txt"),
        study,
    )

    csv_path = joinpath(output_dir, "sequence_constants.csv")
    open(csv_path, "w") do io
        println(
            io,
            "frequency_hz,sequence,zc_magnitude_ohm,zc_angle_deg,attenuation_db_per_mile,velocity_miles_per_s,resistance_ohm_per_mile,reactance_ohm_per_mile,susceptance_mho_per_mile",
        )
        for result in study.frequency_results, row in result.sequence_constants
            @printf(
                io,
                "%.12g,%s,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                result.frequency_hz,
                String(row.sequence),
                row.surge_impedance_magnitude_ohm,
                row.surge_impedance_angle_deg,
                row.attenuation_db_per_mile,
                row.velocity_miles_per_s,
                row.resistance_ohm_per_mile,
                row.reactance_ohm_per_mile,
                row.susceptance_mho_per_mile,
            )
        end
    end

    first_result = first(study.frequency_results)
    sequence_rows = first_result.sequence_constants
    plot_path = write_waveform_svg(
        joinpath(output_dir, "sequence_impedance.svg"),
        collect(1:length(sequence_rows)),
        [
            "surge_impedance_ohm" =>
                [row.surge_impedance_magnitude_ohm for row in sequence_rows],
        ];
        title = "Double-Circuit Sequence Surge Impedance",
        x_label = "sequence row (zero, positive, negative)",
        y_label = "magnitude (ohm)",
    )
    matrix_path = write_matrix_csv(
        joinpath(output_dir, "phase_impedance_matrix.csv"),
        first_result.equivalent_phase_impedance_matrix_ohm_per_mile;
        row_prefix = "phase",
        column_prefix = "phase",
    )

    @printf("Input: %s\n", input_path)
    @printf("Report: %s\n", report_path)
    @printf("Sequence CSV: %s\n", abspath(csv_path))
    @printf("Impedance matrix: %s\n", matrix_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Physical checks passed: %s\n", study.physical_checks_passed)
end

main()
