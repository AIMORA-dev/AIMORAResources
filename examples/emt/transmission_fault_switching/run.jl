#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "CatalogDeckExample.jl")))

using .CatalogDeckExample

run_catalog_deck_example(
    :emt_transmission_fault_switching;
    title = "Three-Phase Transmission Fault and Breaker Sequence",
    interpretation = "The declared 10 ms horizon records the initial faulted response; the 20 ms breaker opening and 96 ms fault clearing are parsed schedules outside this run.",
)
