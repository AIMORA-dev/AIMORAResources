#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0011_transmission_line_reclosing;
    title = "Classic Case 0011 — Transmission-Line Reclosing",
    interpretation = "A receiving-end fault and 20 ms breaker opening leave trapped charge on the distributed line, which controls the subsequent terminal recovery waveform.",
    runtime_t_end_s = 80e-3,
    initial_voltage_source = :steady_state,
)
