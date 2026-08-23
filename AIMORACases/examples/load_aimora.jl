const AIMORA_EXAMPLE_ENGINE_PATH = let
    configured = get(ENV, "AIMORA_ENGINE_PATH", "")
    candidate = normpath(joinpath(@__DIR__, "..", "..", "..", "AIMORA.jl"))
    if !isempty(configured)
        abspath(configured)
    else
        isfile(joinpath(candidate, "src", "AIMORA.jl")) ? candidate : ""
    end
end

if !isempty(AIMORA_EXAMPLE_ENGINE_PATH)
    pushfirst!(LOAD_PATH, AIMORA_EXAMPLE_ENGINE_PATH)
elseif Base.find_package("AIMORA") === nothing
    error(
        "AIMORA is not available. Install AIMORA.jl or set " *
        "AIMORA_ENGINE_PATH to an AIMORA package checkout.",
    )
end
