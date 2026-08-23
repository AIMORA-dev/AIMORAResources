#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExtendedVSCExampleSupport.jl")))

using AIMORA
using .ExtendedVSCExampleSupport

Base.invokelatest(run_extended_vsc_public_case,
    "extended_vsc_virtual_synchronous",
    "Virtual-Synchronous Grid-Forming VSC",
    AIMORA.SwitchDetailedVSC.VirtualSynchronousGridForming,
    AIMORA.SwitchDetailedVSC.LCLFilter,
    AIMORA.SwitchDetailedVSC.FourWireForm,
)
