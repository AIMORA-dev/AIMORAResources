#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_ideal_transformer_type18;
    title = "Type-18 Ideal Transformer",
    interpretation = "The Julia source-routing and ideal-transformer constraint preserve the requested turns ratio through the network solve and output trace.",
)
