#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExtendedVSCExampleSupport.jl")))

using AIMORA
using .ExtendedVSCExampleSupport

Base.invokelatest(run_extended_vsc_public_case,
    "extended_vsc_droop",
    "Power-Droop Grid-Forming VSC",
    AIMORA.SwitchDetailedVSC.PowerDroopGridForming,
    AIMORA.SwitchDetailedVSC.LCLFilter,
    AIMORA.SwitchDetailedVSC.FourWireForm,
)
