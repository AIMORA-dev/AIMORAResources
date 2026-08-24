#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "support", "SurgeInsulationExample.jl")))

output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_public_surge_insulation_products(output_directory)
println("Generic surge and insulation products: ", length(result.specifications))
for (specification, artifacts) in zip(result.specifications, result.results)
    println(specification.id, ": ", artifacts.csv, " | ", artifacts.svg)
end
println("Summary: ", result.summary)
