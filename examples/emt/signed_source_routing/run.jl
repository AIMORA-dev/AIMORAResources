#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_signed_source_routing;
    title = "Signed Source and Control Routing",
    interpretation = "Negative routing identifiers preserve electrical orientation while AIMORA selects the source model by its absolute type and executes the TACS feedback path.",
)
