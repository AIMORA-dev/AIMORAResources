#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0002_parallel_rlc_discharge;
    title = "Classic Case 0002 — Parallel RLC Discharge",
    interpretation = "Closing the switch releases the capacitor's initial energy into the parallel resistance and inductance, producing a damped discharge.",
    runtime_t_end_s = 10e-3,
    initial_voltage_source = :node_conditions,
)
