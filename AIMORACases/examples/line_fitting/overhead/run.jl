include(normpath(joinpath(@__DIR__, "..", "..", "support", "WidebandLineParameterExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    source = line_parameter_example_source("public overhead coupled line fitting")
    frequencies_hz = exp10.(range(0.0, 4.0; length=81))
    segment = example_overhead_segment(
        source,
        example_soil(source);
        frequencies_hz,
    )
    uncertainty_source = line_parameter_example_source(
        "public overhead coupled line fitting soil alternative",
    )
    uncertainty_segment = example_overhead_segment(
        uncertainty_source,
        example_soil(uncertainty_source; resistivity_ohm_m=110.0);
        frequencies_hz,
    )
    artifacts = write_coupled_line_fit_artifacts(
        output_dir,
        segment;
        uncertainty_segments=[uncertainty_segment],
    )
    println(
        "Overhead coupled fit: order=",
        last(artifacts.result.attempts).order,
        " error=",
        artifacts.result.maximum_relative_fit_error,
        " continuous_passivity=",
        artifacts.result.certificate_after_enforcement.continuous_passivity_passed,
    )
end

main()
