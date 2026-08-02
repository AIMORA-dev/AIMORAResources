#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_universal_machine_example(
    :classic_case0015_universal_induction_machine;
    title = "Classic Case 0015 — Universal Induction Machine",
    interpretation = "Automatic type-4 initialization and the coupled d/q timestep expose stator current, rotor speed, flux, and electromagnetic torque together.",
)
