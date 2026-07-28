const AIMORA_EXAMPLE_ENGINE_PATH = let
    configured = get(ENV, "AIMORA_ENGINE_PATH", "")
    workspace_candidate = normpath(
        joinpath(@__DIR__, "..", "..", "AIMORA.jl"),
    )
    if !isempty(configured)
        abspath(configured)
    elseif isfile(joinpath(workspace_candidate, "src", "AIMORA.jl"))
        workspace_candidate
    else
        ""
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
