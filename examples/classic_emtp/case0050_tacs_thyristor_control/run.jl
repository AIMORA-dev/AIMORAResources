#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0050_tacs_thyristor_control;
    title = "Classic Case 0050 — TACS Thyristor Control",
    interpretation = "Integrated valve voltage is compared with the firing reference and drives the two antiparallel thyristor switch commands.",
    runtime_t_end_s = 0.1,
)
