#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0007_capacitor_bank_recovery_voltage;
    title = "Classic Case 0007 — Capacitor Recovery Voltage",
    interpretation = "Opening the three bank switches at 1 ms traps capacitor charge while the source continues at 60 Hz, creating switch recovery voltage.",
    runtime_t_end_s = 50e-3,
    initial_voltage_source = :steady_state,
)
