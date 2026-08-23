#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_hysteretic_inductor_runtime;
    title = "Hysteretic Inductor Runtime",
    interpretation = "The type-96 characteristic, incremental companion, history current, sparse solve, and output trace advance together through the Julia EMT runtime.",
)
