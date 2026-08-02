#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_steady_state_example(
    :classic_case0010_parallel_ehv_resonance;
    title = "Classic Case 0010 — Parallel EHV Resonance",
    interpretation = "The 60 Hz phasor solution exposes voltage magnification from the long coupled PI-section network, series capacitors, shunt reactors, and fault branch.",
)
