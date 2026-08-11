#!/usr/bin/env julia

using Printf
using LinearAlgebra

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.TransformerParameters
using .ExampleSupport

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    input = TransformerShortCircuitCase(
        1,
        [132.0, 33.0],
        [420.0],
        [10.5],
        [100.0],
        0.8,
        100.0,
        [(:H1, :H0), (:X1, :X0)],
    )
    result = transformer_short_circuit_parameters(input)
    result.physical_checks_passed ||
        error("transformer physical checks did not pass")

    impedance_path = write_matrix_csv(
        joinpath(output_dir, "impedance_matrix_ohm.csv"),
        result.impedance_matrix_ohm;
        row_prefix = "winding",
        column_prefix = "winding",
    )
    admittance_path = write_matrix_csv(
        joinpath(output_dir, "admittance_matrix_s.csv"),
        result.admittance_matrix_s;
        row_prefix = "winding",
        column_prefix = "winding",
    )
    plot_path = write_waveform_svg(
        joinpath(output_dir, "winding_impedance.svg"),
        collect(1:size(result.impedance_matrix_ohm, 1)),
        [
            "resistance_ohm" => real.(diag(result.impedance_matrix_ohm)),
            "reactance_ohm" => imag.(diag(result.impedance_matrix_ohm)),
        ];
        title = "Two-Winding Equivalent Self Impedance",
        x_label = "winding",
        y_label = "ohm",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Two-Winding Short-Circuit Conversion",
        (
            rated_voltages_kv = input.winding_voltages_kv,
            pair_loss_kw = only(input.pair_losses_kw),
            pair_impedance_percent = only(input.pair_impedance_percent),
            pair_rating_mva = only(input.pair_ratings_mva),
            inverse_residual = result.inverse_residual,
            symmetry_residual = result.symmetry_residual,
            physical_checks_passed = result.physical_checks_passed,
        ),
    )

    @printf("Impedance matrix: %s\n", impedance_path)
    @printf("Admittance matrix: %s\n", admittance_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
