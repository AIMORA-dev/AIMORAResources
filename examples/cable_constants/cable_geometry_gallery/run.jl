#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.CableConstantsStudy
using AIMORA.DeckParser
using AIMORA.ReportArtifacts
using .ExampleSupport

const GEOMETRIES = (
    :type2_one_layer,
    :type2_two_layer,
    :type3_centered_one_layer,
    :type3_offcenter_two_layer,
)

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    rows = NamedTuple[]
    for name in GEOMETRIES
        input_path = joinpath(@__DIR__, "$(name).deck")
        parsed = parse_example_deck(input_path)
        assert_deck_valid!(parsed)
        study = run_cable_constants_study(parsed)
        study.physical_checks_passed ||
            error("cable geometry $(name) failed a physical check")
        state = first(study.frequency_states)
        report_path = joinpath(output_dir, "$(name)_report.txt")
        write_cable_constants_report_text(report_path, study)
        push!(rows, (
            name,
            conductor_count = size(state.series_impedance_matrix_ohm_per_m, 1),
            frequency_count = length(study.frequency_states),
            frequency_hz = state.frequency_hz,
            zc_ohm = abs(first(state.modal_characteristic_impedance_ohm)),
            velocity_m_per_s = first(state.modal_velocity_m_per_s),
            checks = study.physical_checks_passed,
        ))
    end
    metrics_path = joinpath(output_dir, "cable_geometry_metrics.csv")
    open(metrics_path, "w") do io
        println(io, "geometry,conductor_count,frequency_count,first_frequency_hz,mode1_zc_magnitude_ohm,mode1_velocity_m_per_s,physical_checks_passed")
        for row in rows
            @printf(
                io,
                "%s,%d,%d,%.12g,%.12g,%.12g,%s\n",
                String(row.name),
                row.conductor_count,
                row.frequency_count,
                row.frequency_hz,
                row.zc_ohm,
                row.velocity_m_per_s,
                row.checks,
            )
        end
    end
    plot_path = write_waveform_svg(
        joinpath(output_dir, "cable_geometry_impedance.svg"),
        collect(eachindex(rows)),
        ["mode1_zc_magnitude_ohm" => [row.zc_ohm for row in rows]];
        title = "Cable Geometry and First-Mode Characteristic Impedance",
        x_label = "geometry index (type2-1L, type2-2L, type3-centred, type3-offset)",
        y_label = "characteristic impedance magnitude (ohm)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Cable Geometry Gallery",
        (
            julia_only = true,
            geometry_count = length(rows),
            all_physical_checks_passed = all(row -> row.checks, rows),
            interpretation =
                "Additional dielectric layers and pipe/core geometry alter the reduced modal impedance while all matrices remain finite, symmetric, and physically admissible.",
        ),
    )
    @printf("Metrics: %s\n", abspath(metrics_path))
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
