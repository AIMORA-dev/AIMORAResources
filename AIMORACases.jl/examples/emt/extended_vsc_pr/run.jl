#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExtendedVSCExampleSupport.jl")))

using AIMORA
using .ExtendedVSCExampleSupport

Base.invokelatest(run_extended_vsc_public_case,
    "extended_vsc_pr",
    "Stationary PR Grid-Following VSC",
    AIMORA.SwitchDetailedVSC.StationaryResonantGridFollowing,
    AIMORA.SwitchDetailedVSC.ShuntLCFilter,
    AIMORA.SwitchDetailedVSC.ThreeWireForm,
)
