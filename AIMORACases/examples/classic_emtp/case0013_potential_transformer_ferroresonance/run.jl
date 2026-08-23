#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ClassicEMTPExample.jl")))

using .ClassicEMTPExample

run_classic_transient_example(
    :classic_case0013_potential_transformer_ferroresonance;
    title = "Classic Case 0013 — Potential-Transformer Ferroresonance",
    interpretation = "Breaker grading capacitance exchanges energy with the nonlinear transformer magnetizing branch after the 20 ms source-side opening.",
    runtime_t_end_s = 0.2,
    initial_voltage_source = :steady_state,
    saturated_transformer_branch_runtime_enabled = true,
    coupled_lumped_sequence_history_enabled = true,
)
