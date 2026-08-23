#!/usr/bin/env julia

using Printf
using LinearAlgebra

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.TransformerParameters
using .ExampleSupport

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    windings = [
        TransformerParameterWinding(1, :H1, :H0, 0.20, 5.0, 132.0),
        TransformerParameterWinding(2, :X1, :X0, 0.10, 2.0, 33.0),
    ]
    input = SaturableTransformerParameterCase(
        1,
        60.0,
        0.0,
        0.5,
        1.2,
        1000.0,
        windings,
    )
    result = saturable_transformer_parameters(input)
    result.physical_checks_passed ||
        error("saturable-transformer physical checks did not pass")

    resistance_path = write_matrix_csv(
        joinpath(output_dir, "branch_resistance_matrix_ohm.csv"),
        result.branch_resistance_matrix_ohm;
        row_prefix = "winding",
        column_prefix = "winding",
    )
    inductance_path = write_matrix_csv(
        joinpath(output_dir, "physical_inductance_matrix_h.csv"),
        result.physical_inductance_matrix_h;
        row_prefix = "winding",
        column_prefix = "winding",
    )
    plot_path = write_waveform_svg(
        joinpath(output_dir, "winding_inductance.svg"),
        collect(1:length(windings)),
        ["self_inductance_h" => diag(result.physical_inductance_matrix_h)];
        title = "Saturable Transformer Self Inductance",
        x_label = "winding",
        y_label = "henry",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Saturable Two-Winding Transformer",
        (
            magnetizing_parallel_inductance_h =
                result.magnetizing_parallel_inductance_h,
            magnetizing_reactance_ohm = result.magnetizing_reactance_ohm,
            equivalent_series_resistance_ohm =
                result.equivalent_series_resistance_ohm,
            equivalent_series_inductance_h =
                result.equivalent_series_inductance_h,
            symmetry_residual = result.symmetry_residual,
            physical_checks_passed = result.physical_checks_passed,
        ),
    )

    @printf("Resistance matrix: %s\n", resistance_path)
    @printf("Inductance matrix: %s\n", inductance_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
