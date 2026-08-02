#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_line_constants_example(
    :classic_case0005_345kv_double_circuit;
    title = "Classic Case 0005 — 345 kV Double Circuit",
    interpretation = "Mutual electromagnetic coupling between the two circuits appears in the phase matrix before sequence reduction.",
)
