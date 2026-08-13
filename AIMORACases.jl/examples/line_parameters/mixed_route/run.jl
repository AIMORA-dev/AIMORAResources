include(normpath(joinpath(@__DIR__, "..", "..", "support", "WidebandLineParameterExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    source = line_parameter_example_source("public mixed overhead and cable route")
    soil_source = line_parameter_example_source("public two-layer soil")
    soil = LineSoilProfile([
        LineSoilLayer(100.0, 10.0, 1.0, 2.0, soil_source),
        LineSoilLayer(300.0, 10.0, 1.0, nothing, soil_source),
    ]; profile_id=:public_two_layer_soil)
    overhead = example_overhead_segment(source, soil; length_m=750.0)
    cable = example_cable_segment(
        source,
        soil;
        length_m=250.0,
        phase_order=[:phase_c, :phase_a, :phase_b],
    )
    parameters = line_parameter_set(:public_mixed_route, [overhead, cable])
    parameters.diagnostics.physical_checks_passed || error("physical checks failed")
    artifacts = write_line_parameter_artifacts(output_dir, parameters)
    println("Mixed-route line parameter artifacts: ", artifacts)
end

main()
