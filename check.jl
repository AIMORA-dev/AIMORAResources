#!/usr/bin/env julia

using AIMORACases
using TOML

const ROOT = @__DIR__

fail(message) = error("AIMORA case package check failed: $(message)")

for relative_path in (
    "Project.toml",
    "README.md",
    "cases/catalog.toml",
    "src/AIMORACases.jl",
    "test/runtests.jl",
    "examples/list_cases.jl",
    "examples/emt/inverter/run.jl",
    "examples/emt/generated_ieee13_deck/ieee13_minimum_core.deck",
)
    isfile(joinpath(ROOT, relative_path)) || fail("missing $(relative_path)")
end

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
get(project, "name", nothing) == "AIMORACases" ||
    fail("Project.toml name is not AIMORACases")

cases = AIMORACases.available_cases()
isempty(cases) && fail("case catalog is empty")
for case in cases
    isfile(AIMORACases.case_path(case.id)) || fail("missing case file for $(case.id)")
    isempty(strip(case.description)) && fail("case $(case.id) has no description")
end

emt_examples_root = joinpath(ROOT, "examples", "emt")
emt_examples = sort(filter(isdir, readdir(emt_examples_root; join = true)))
isempty(emt_examples) && fail("no runnable EMT examples")
for example_root in emt_examples
    isfile(joinpath(example_root, "run.jl")) ||
        fail("missing run.jl for $(basename(example_root))")
    isfile(joinpath(example_root, "Makefile")) ||
        fail("missing Makefile for $(basename(example_root))")
end

for (directory, _, files) in walkdir(ROOT)
    for filename in files
        extension = lowercase(splitext(filename)[2])
        extension in (".f", ".for", ".ftn", ".f90", ".f95") &&
            fail("Fortran source belongs in BPAEMTPReference.jl: $(joinpath(directory, filename))")
    end
end

for forbidden_path in ("AGENTS.md", "MEMORY.md", "TRANSLATION_MAP.md", ".codex", "runs")
    !ispath(joinpath(ROOT, forbidden_path)) ||
        fail("development-only path is present: $(forbidden_path)")
end

println("AIMORA case package check passed")
