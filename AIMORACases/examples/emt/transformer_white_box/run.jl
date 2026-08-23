include(normpath(joinpath(@__DIR__, "..", "..", "support", "TransformerApparatusExample.jl")))

output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_transformer_product(output_dir, :emt_transformer_white_box)
println("White-box transformer product: steps=", result.result.accepted_step_count,
    " restart_exact=", result.restart_exact)
