include(normpath(joinpath(@__DIR__, "..", "..", "support", "MeasurementChainExample.jl")))

output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_measurement_product(output_dir, :emt_measurement_electronic_current)
println("Electronic current-sensor product: steps=", length(result.rows),
    " samples=", length(result.released_samples), " restart_exact=", result.restart_exact)
