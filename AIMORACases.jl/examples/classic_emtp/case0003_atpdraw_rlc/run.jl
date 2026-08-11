#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0003_atpdraw_rlc;
    title = "Classic Case 0003 — ATPDraw RLC Network",
    interpretation = "The 12-unit step and the 10 ms switch event expose the response of the ATPDraw-authored RLC topology and its specified initial conditions.",
    runtime_t_end_s = 50e-3,
    initial_voltage_source = :zero,
)
