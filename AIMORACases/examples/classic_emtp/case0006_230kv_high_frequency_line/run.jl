#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_line_constants_example(
    :classic_case0006_230kv_high_frequency_line;
    title = "Classic Case 0006 — 230 kV High-Frequency Line",
    interpretation = "The 500 kHz study emphasizes the geometry-controlled surge quantities used for fast-front travelling-wave work.",
)
