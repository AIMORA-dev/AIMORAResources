#!/usr/bin/env julia

using AIMORACatalogs
using TOML

const ROOT = @__DIR__

fail(message) = error("AIMORA catalog package check failed: $(message)")

for relative_path in (
    "Project.toml",
    "README.md",
    "src/AIMORACatalogs.jl",
    "test/runtests.jl",
    "examples/list_assets.jl",
)
    isfile(joinpath(ROOT, relative_path)) || fail("missing $(relative_path)")
end

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
get(project, "name", nothing) == "AIMORACatalogs" ||
    fail("Project.toml name is not AIMORACatalogs")

assets = AIMORACatalogs.available_assets()
isempty(assets) && fail("equipment catalog is empty")
for entry in assets
    isempty(strip(entry.provenance)) && fail("asset $(entry.id) has no provenance")
    isempty(strip(entry.licence)) && fail("asset $(entry.id) has no licence")
    isfile(AIMORACatalogs.asset_path(entry.id)) || fail("missing asset file for $(entry.id)")
end

for forbidden_path in ("AGENTS.md", "MEMORY.md", "TRANSLATION_MAP.md", ".codex", "runs")
    !ispath(joinpath(ROOT, forbidden_path)) ||
        fail("development-only path is present: $(forbidden_path)")
end

println("AIMORA catalog package check passed")
