#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.EMTStudy
using .ExampleSupport

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    branches = FaultSequenceBranch[
        FaultSequenceBranch(1, 0, 10.0),
        FaultSequenceBranch(2, 0, 12.0),
        FaultSequenceBranch(1, 2, 5.0),
    ]
    network = fault_sequence_admittance_matrix(2, branches)
    target = [2.0, 2.5]
    fit = fit_fault_generator_equivalent(
        network,
        target;
        sequence_kind = :positive,
        frequency_hz = 60.0,
        target_x_over_r = [10.0, 20.0],
    )
    node = [1.0, 2.0]
    csv_path = write_series_csv(
        joinpath(output_dir, "fault_equivalent_fit.csv"),
        "node",
        node,
        [
            "target_reactance_ohm" => fit.target_thevenin_reactance_ohm,
            "reconstructed_reactance_ohm" =>
                fit.reconstructed_thevenin_reactance_ohm,
            "residual_ohm" => fit.residual_ohm,
            "generator_resistance_ohm" => fit.generator_resistance_ohm,
            "generator_reactance_ohm" => fit.generator_reactance_ohm,
        ],
    )
    matrix_path = write_matrix_csv(
        joinpath(output_dir, "network_admittance.csv"),
        network;
        row_prefix = "node",
        column_prefix = "node",
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "fault_equivalent_fit.svg"),
        node,
        [
            "target_X_th" => fit.target_thevenin_reactance_ohm,
            "reconstructed_X_th" => fit.reconstructed_thevenin_reactance_ohm,
        ];
        title = "Fault Generator-Equivalent Fit",
        x_label = "sequence-network node",
        y_label = "driving-point reactance (ohm)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Fault Generator-Equivalent Fitting",
        (
            converged = fit.converged,
            iterations = fit.iteration_count,
            reciprocal = fit.reciprocal,
            passive = fit.passive,
            maximum_residual_ohm = fit.maximum_residual_ohm,
            julia_only = true,
        ),
    )
    @printf("Fit CSV: %s\n", csv_path)
    @printf("Network matrix: %s\n", matrix_path)
    @printf("Plot: %s\n", svg_path)
    @printf("Summary: %s\n", summary_path)
end

main()
