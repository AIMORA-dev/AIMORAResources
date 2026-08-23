#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExtendedVSCExampleSupport.jl")))

using AIMORA
using .ExtendedVSCExampleSupport

Base.invokelatest(run_extended_vsc_public_case,
    "extended_vsc_pll_dq",
    "Synchronous PLL-dq Grid-Following VSC",
    AIMORA.SwitchDetailedVSC.SynchronousPLLGridFollowing,
    AIMORA.SwitchDetailedVSC.SeriesLFilter,
    AIMORA.SwitchDetailedVSC.ThreeWireForm,
)
