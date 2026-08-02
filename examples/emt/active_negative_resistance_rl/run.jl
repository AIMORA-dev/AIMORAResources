#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_active_negative_resistance_rl;
    title = "Finite Active Negative-Resistance R–L Branch",
    interpretation = "The negative physical resistance is accepted because the trapezoidal R–L companion denominator remains finite and nonsingular, producing a bounded Julia waveform.",
)
