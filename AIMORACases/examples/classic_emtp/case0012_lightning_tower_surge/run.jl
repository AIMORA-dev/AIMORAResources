#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0012_lightning_tower_surge;
    title = "Classic Case 0012 — Lightning Tower Surge",
    interpretation = "The fast current impulse launches travelling waves along the tower and line sections; the plotted insulator voltages show the first microseconds of the surge.",
    runtime_t_end_s = 6e-6,
)
