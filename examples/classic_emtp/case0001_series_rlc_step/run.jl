#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0001_series_rlc_step;
    title = "Classic Case 0001 — Series RLC Step",
    interpretation = "The step source drives a damped second-order exchange of energy between the series inductor and shunt capacitor.",
    runtime_t_end_s = 10e-3,
    initial_voltage_source = :zero,
)
