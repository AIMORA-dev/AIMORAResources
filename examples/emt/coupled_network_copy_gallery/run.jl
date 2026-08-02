#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "MultiDeckGallery.jl")))

using .MultiDeckGallery

const CASES = (
    (
        name = :four_phase_coupled_rl,
        path = joinpath(@__DIR__, "four_phase_coupled_rl.deck"),
        title = "Four-Phase Coupled R–L Network",
    ),
    (
        name = :coupled_rl_copy,
        path = joinpath(@__DIR__, "coupled_rl_copy.deck"),
        title = "Coupled R–L COPY Network",
    ),
    (
        name = :distributed_line_copy,
        path = joinpath(@__DIR__, "distributed_line_copy.deck"),
        title = "Distributed-Line COPY Network",
    ),
)

run_deck_gallery(
    CASES;
    gallery_title = "Coupled Network and COPY Gallery",
    interpretation = "AIMORA preserves complete coupled matrices and copied physical parameters while replacing terminals and allocating independent dynamic histories for each copied network.",
)
