include(normpath(joinpath(@__DIR__, "..", "..", "support", "TransformerApparatusExample.jl")))

output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_transformer_product(output_dir, :emt_transformer_bctran)
println("BCTRAN transformer product: steps=", result.result.accepted_step_count,
    " restart_exact=", result.restart_exact)
