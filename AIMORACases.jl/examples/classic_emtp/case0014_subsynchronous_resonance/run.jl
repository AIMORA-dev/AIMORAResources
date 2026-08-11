#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_synchronous_machine_example(
    :classic_case0014_subsynchronous_resonance;
    title = "Classic Case 0014 — Subsynchronous Resonance",
    interpretation = "The series-compensated network and four-mass shaft exchange electrical and torsional energy after the short three-phase disturbance.",
    runtime_t_end_s = 0.2,
)
