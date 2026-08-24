#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "support", "ProtectionProductExample.jl")))

output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_public_protection_products(output_directory)
println("Generic fixed-step protection products: ", length(result.results))
for (product, artifacts) in zip(result.results, result.artifacts)
    println(
        product.specification.id,
        ": ",
        artifacts.csv,
        " | ",
        artifacts.svg,
        " | ",
        artifacts.snapshot,
    )
end
println("Protection logic: ", result.logic_diagram)
println("C-loopback parity: ", result.c_loopback.csv)
