#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "MultiDeckGallery.jl")))

using .MultiDeckGallery

const CASES = (
    (
        name = :fixed_field_type16,
        path = joinpath(@__DIR__, "fixed_field_type16.deck"),
        title = "Fixed-Field Type-16 DC Simulator",
    ),
    (
        name = :free_field_type16,
        path = joinpath(@__DIR__, "free_field_type16.deck"),
        title = "Free-Field Type-16 DC Simulator",
    ),
)

run_deck_gallery(
    CASES;
    gallery_title = "Type-16 DC-Simulator Source Gallery",
    interpretation = "Fixed- and free-field two-card inputs construct the same typed controller, generated resistor/switch topology, initialized source rows, and timestep outputs.",
)
