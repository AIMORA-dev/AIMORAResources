#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0009_capacitor_restrike;
    title = "Classic Case 0009 — Capacitor-Switch Restrike",
    interpretation = "The phase-A interruption and 11.1 ms restrike create a steep recovery transient while the other phases remain energized.",
    runtime_t_end_s = 1.0,
    initial_voltage_source = :zero,
)
