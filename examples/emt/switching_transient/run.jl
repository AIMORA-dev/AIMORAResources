#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_switching_transient;
    title = "Timed Switching Transient",
    interpretation = "The BUS2–BUS3 tie closes at 40 microseconds, changing the solved topology and energizing the downstream load.",
)
