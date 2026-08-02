#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.Nonlinear
using .ExampleSupport

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))

    saturation = saturation_from_incremental_inductance(
        [0.0, 1.0, 2.0, 4.0, 8.0],
        [0.50, 0.45, 0.30, 0.16, 0.08],
    )
    saturation_csv = write_series_csv(
        joinpath(output_dir, "saturation_curve.csv"),
        "current_a",
        saturation.current_a,
        ["flux_wb" => saturation.flux_wb],
    )
    saturation_svg = write_waveform_svg(
        joinpath(output_dir, "saturation_curve.svg"),
        saturation.current_a,
        ["flux_wb" => saturation.flux_wb];
        title = "Integrated Saturation Characteristic",
        x_label = "current (A)",
        y_label = "flux linkage (Wb)",
    )

    hysteresis = normalized_hysteresis_loop(3, 8.0, 1.6)
    hysteresis_csv = write_series_csv(
        joinpath(output_dir, "hysteresis_loop.csv"),
        "current_a",
        hysteresis.closed_loop_current_a,
        ["flux_wb" => hysteresis.closed_loop_flux_wb],
    )
    hysteresis_svg = write_waveform_svg(
        joinpath(output_dir, "hysteresis_loop.svg"),
        collect(eachindex(hysteresis.closed_loop_current_a)),
        [
            "current_a" => hysteresis.closed_loop_current_a,
            "flux_wb" => hysteresis.closed_loop_flux_wb,
        ];
        title = "Closed Hysteresis Loop",
        x_label = "ordered loop sample",
        y_label = "physical value",
    )

    measured_current = [1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1]
    measured_voltage = [20.0, 23.0, 27.0, 32.0, 38.0, 45.0]
    zno = zinc_oxide_piecewise_fit(
        measured_current,
        measured_voltage;
        relative_error_tolerance = 0.02,
        maximum_segments = 5,
    )
    zno_csv = write_series_csv(
        joinpath(output_dir, "zinc_oxide_fit.csv"),
        "voltage_v",
        zno.sample_voltage_v,
        [
            "measured_current_a" => zno.sample_current_a,
            "fitted_current_a" => zno.fitted_current_a,
        ],
    )
    zno_svg = write_waveform_svg(
        joinpath(output_dir, "zinc_oxide_fit.svg"),
        zno.sample_voltage_v,
        [
            "measured_current_a" => zno.sample_current_a,
            "fitted_current_a" => zno.fitted_current_a,
        ];
        title = "ZnO Piecewise Power-Law Fit",
        x_label = "voltage (V)",
        y_label = "current (A)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Nonlinear Characteristic Gallery",
        (
            saturation_monotone = saturation.monotone,
            hysteresis_energy_loss_j = hysteresis.energy_loss_j,
            hysteresis_closure_error = hysteresis.closure_error,
            zinc_oxide_segments = length(zno.segments),
            zinc_oxide_maximum_relative_error =
                zno.maximum_relative_current_error,
            zinc_oxide_continuity_error_a = zno.continuity_error_a,
            physical_checks_passed =
                saturation.physical_checks_passed &&
                hysteresis.physical_checks_passed &&
                zno.fit_checks_passed,
            julia_only = true,
        ),
    )
    @printf("Saturation: %s, %s\n", saturation_csv, saturation_svg)
    @printf("Hysteresis: %s, %s\n", hysteresis_csv, hysteresis_svg)
    @printf("ZnO: %s, %s\n", zno_csv, zno_svg)
    @printf("Summary: %s\n", summary_path)
end

main()
