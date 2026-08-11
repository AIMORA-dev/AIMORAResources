#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "MultiDeckGallery.jl")))

using .MultiDeckGallery

const CASES = (
    (
        name = :named_type96_hysteretic,
        path = joinpath(@__DIR__, "named_type96_hysteretic.deck"),
        title = "Named Type-96 Hysteretic Inductor",
    ),
    (
        name = :type98_pseudo_nonlinear,
        path = joinpath(@__DIR__, "type98_pseudo_nonlinear.deck"),
        title = "Standalone Type-98 Pseudo-Nonlinear Inductor",
    ),
)

run_deck_gallery(
    CASES;
    gallery_title = "Nonlinear Identity and Type-98 Gallery",
    interpretation = "The NONLIN moniker binds the next nonlinear owner, while public type 98 executes its transformed piecewise characteristic through sparse stamping, history mutation, and reported waveforms.",
)
