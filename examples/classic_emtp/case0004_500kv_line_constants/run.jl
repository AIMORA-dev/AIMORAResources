#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_line_constants_example(
    :classic_case0004_500kv_line_constants;
    title = "Classic Case 0004 — 500 kV Line Constants",
    interpretation = "The flat bundled phase geometry and two shield wires produce passive phase matrices and distinct zero- and positive-sequence surge impedances.",
)
