include(normpath(joinpath(@__DIR__, "..", "..", "support", "WidebandLineParameterExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    source = line_parameter_example_source("public separately fitted mixed route")
    soil = example_soil(source)
    frequencies_hz = exp10.(range(0.0, 4.0; length=81))
    overhead = example_overhead_segment(
        source,
        soil;
        id=:mixed_route_overhead,
        length_m=1000.0,
        frequencies_hz,
    )
    cable = example_cable_segment(
        source,
        soil;
        id=:mixed_route_cable,
        length_m=500.0,
        phase_order=[:phase_c, :phase_a, :phase_b],
        frequencies_hz,
    )
    uncertainty_source = line_parameter_example_source(
        "public mixed route fitting soil alternative",
    )
    uncertainty_soil = example_soil(uncertainty_source; resistivity_ohm_m=110.0)
    overhead_alternative = example_overhead_segment(
        uncertainty_source,
        uncertainty_soil;
        id=:mixed_route_overhead,
        length_m=1000.0,
        frequencies_hz,
    )
    cable_alternative = example_cable_segment(
        uncertainty_source,
        uncertainty_soil;
        id=:mixed_route_cable,
        length_m=500.0,
        phase_order=[:phase_c, :phase_a, :phase_b],
        frequencies_hz,
    )
    overhead_artifacts = write_coupled_line_fit_artifacts(
        output_dir,
        overhead;
        prefix="overhead_segment",
        uncertainty_segments=[overhead_alternative],
    )
    cable_artifacts = write_coupled_line_fit_artifacts(
        output_dir,
        cable;
        prefix="cable_segment",
        uncertainty_segments=[cable_alternative],
    )
    write_key_value_summary(
        joinpath(output_dir, "mixed_route_fit_summary.txt"),
        "Separately Fitted Mixed Route",
        (
        route_representation="separately_fitted_uniform_segments",
        segment_order="mixed_route_overhead,mixed_route_cable",
        overhead_source_signature_sha256=overhead.input_signature_sha256,
        overhead_fit_signature_sha256=
            overhead_artifacts.result.deterministic_signature_sha256,
        cable_source_signature_sha256=cable.input_signature_sha256,
        cable_fit_signature_sha256=
            cable_artifacts.result.deterministic_signature_sha256,
        length_averaged_uniform_fit_created=false,
        runtime_executed=false,
        ),
    )
    println(
        "Mixed route fitted as two uniform segments: overhead order=",
        last(overhead_artifacts.result.attempts).order,
        " cable order=",
        last(cable_artifacts.result.attempts).order,
    )
end

main()
