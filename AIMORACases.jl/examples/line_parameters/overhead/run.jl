include(normpath(joinpath(@__DIR__, "..", "..", "support", "WidebandLineParameterExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    source = line_parameter_example_source("public overhead line geometry")
    segment = example_overhead_segment(source, example_soil(source))
    parameters = line_parameter_set(:public_overhead_route, [segment])
    parameters.diagnostics.physical_checks_passed || error("physical checks failed")
    artifacts = write_line_parameter_artifacts(output_dir, parameters)
    println("Overhead line parameter artifacts: ", artifacts)
end

main()
