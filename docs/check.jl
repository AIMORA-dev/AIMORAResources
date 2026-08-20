#!/usr/bin/env julia

const REPOSITORY_ROOT = @__DIR__
const AIMORA_PATH = let
    configured = strip(get(ENV, "AIMORA_DOCS_ENGINE_PATH", ""))
    workspace_candidate = normpath(joinpath(REPOSITORY_ROOT, "..", "..", "AIMORA.jl"))
    if !isempty(configured)
        abspath(configured)
    elseif isfile(joinpath(workspace_candidate, "src", "AIMORA.jl"))
        workspace_candidate
    else
        ""
    end
end

fail(message) = error("Documentation check failed: $(message)")

const REQUIRED_FILES = (
    "README.md",
    "make.jl",
    "src/index.md",
    "src/getting-started.md",
    "src/architecture.md",
    "src/studies.md",
    "src/wideband-line-parameters.md",
    "src/transformer-reactor-hierarchy.md",
    "src/emt-measurement-chains.md",
    "src/cases-and-catalogs.md",
    "src/validation.md",
    "src/development.md",
    "src/api.md",
)

for relative_path in REQUIRED_FILES
    isfile(joinpath(REPOSITORY_ROOT, relative_path)) ||
        fail("missing required file $(relative_path)")
end

const PUBLICATION_FORBIDDEN = (
    "AIMORAWorkspace",
    "AIMORAValidation",
    "AIMORASolvers.jl",
    "AGENTS.md",
    "MEMORY.md",
    "TRANSLATION_",
    ".codex",
    "git@github.com",
    "/home/",
)

markdown_files = [
    joinpath(REPOSITORY_ROOT, "README.md");
    [
        joinpath(REPOSITORY_ROOT, "src", name)
        for name in readdir(joinpath(REPOSITORY_ROOT, "src"))
        if endswith(name, ".md")
    ]
]

function check_markdown(path::AbstractString)
    text = read(path, String)
    for forbidden in PUBLICATION_FORBIDDEN
        occursin(forbidden, text) &&
            fail("internal information $(repr(forbidden)) in $(relpath(path, REPOSITORY_ROOT))")
    end
    for matched_link in eachmatch(r"\[[^\]]*\]\(([^)]+)\)", text)
        target = strip(matched_link.captures[1])
        isempty(target) && continue
        any(prefix -> startswith(target, prefix), ("http://", "https://", "mailto:", "#")) &&
            continue
        local_target = split(target, "#"; limit = 2)[1]
        isempty(local_target) && continue
        ispath(normpath(joinpath(dirname(path), local_target))) ||
            fail("broken local link $(target) in $(relpath(path, REPOSITORY_ROOT))")
    end
end

foreach(check_markdown, markdown_files)

!isempty(AIMORA_PATH) && isfile(joinpath(AIMORA_PATH, "src", "AIMORA.jl")) ||
    fail("place AIMORA.jl beside this checkout or set AIMORA_DOCS_ENGINE_PATH")
pushfirst!(LOAD_PATH, AIMORA_PATH)
using AIMORA

study_ids = Set(study.id for study in AIMORA.StudyCatalog.available_studies())
for required_study in (:emt, :power_flow, :short_circuit, :protection, :arc_flash)
    required_study in study_ids || fail("public package is missing study $(required_study)")
end

println("AIMORA public documentation check passed")
