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
        MultiphaseTransformerWinding(
            1,
            230.0,
            0.12,
            ((:H1, :H0), (:H2, :H0), (:H3, :H0)),
        ),
        MultiphaseTransformerWinding(
            2,
            69.0,
            0.06,
            ((:X1, :X0), (:X2, :X0), (:X3, :X0)),
        ),
    ]
    tests = [
        TransformerSequenceShortCircuitTest(
            1,
            2,
            350.0,
            9.0,
            150.0,
            10.5,
            150.0,
        ),
    ]
    input = MultiphaseTransformerParameterCase(
        1,
        60.0,
        0.7,
        150.0,
        80.0,
        0.9,
        150.0,
        95.0,
        3,
        1,
        1,
        :reactance,
        false,
        windings,
        tests,
    )
    result = multiphase_transformer_parameters(input)
    result.physical_checks_passed ||
        error("multiphase-transformer physical checks did not pass")

    reactance_path = write_matrix_csv(
        joinpath(output_dir, "reactance_matrix_ohm.csv"),
        result.reactance_matrix_ohm;
        row_prefix = "terminal",
        column_prefix = "terminal",
    )
    resistance_path = write_matrix_csv(
        joinpath(output_dir, "resistance_matrix_ohm.csv"),
        result.resistance_matrix_ohm;
        row_prefix = "terminal",
        column_prefix = "terminal",
    )
    diagonal = diag(result.reactance_matrix_ohm)
    plot_path = write_waveform_svg(
        joinpath(output_dir, "terminal_self_reactance.svg"),
        collect(eachindex(diagonal)),
        ["self_reactance_ohm" => diagonal];
        title = "Multiphase Transformer Terminal Reactance",
        x_label = "phase terminal",
        y_label = "ohm",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Multiphase Sequence-Test Conversion",
        (
            phase_count = input.phase_count,
            winding_count = length(input.windings),
            generated_branch_count = length(result.generated_branches),
            positive_pair_reconstruction_residual =
                result.positive_pair_reconstruction_residual,
            zero_pair_reconstruction_residual =
                result.zero_pair_reconstruction_residual,
            symmetry_residual = result.symmetry_residual,
            physical_checks_passed = result.physical_checks_passed,
        ),
    )

    @printf("Reactance matrix: %s\n", reactance_path)
    @printf("Resistance matrix: %s\n", resistance_path)
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
