#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0008_back_to_back_capacitor_banks;
    title = "Classic Case 0008 — Back-to-Back Capacitor Banks",
    interpretation = "The first bank closes at 0.5 ms and the second at 17.2 ms; the current-limiting reactors bound the high-frequency exchange between banks.",
    runtime_t_end_s = 40e-3,
    initial_voltage_source = :zero,
)
