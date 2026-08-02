#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_control_network_feedback;
    title = "TACS Network Feedback",
    interpretation = "The sensed network voltage, first-order filter, controlled sources, and switch mutate in the Julia timestep order and produce finite closed-loop channels.",
)
