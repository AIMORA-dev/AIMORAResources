#!/usr/bin/env julia

using TOML

const ROOT = @__DIR__
const SOURCE_ROOT = joinpath(ROOT, "src", "fortran")

fail(message) = error("BPA EMTP reference check failed: $(message)")

for relative_path in (
    "Project.toml",
    "README.md",
    "LEGACY-NOTICE.md",
    "src/BPAEMTPReference.jl",
    "src/julia/preprocess_fortran.jl",
    "scripts/build_fortran.sh",
    "examples/emt/rlc_energization/rlc_energization.deck",
    "examples/emt/rlc_energization/run.jl",
    "test/runtests.jl",
)
    isfile(joinpath(ROOT, relative_path)) || fail("missing $(relative_path)")
end

for source_name in ("MAIN00.FOR", "OVER16.FOR", "OVER44.FOR", "TACSTO.INS")
    isfile(joinpath(SOURCE_ROOT, source_name)) || fail("missing historical source $(source_name)")
end

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
get(project, "name", nothing) == "BPAEMTPReference" ||
    fail("Project.toml name is not BPAEMTPReference")

for forbidden_path in (
    "AGENTS.md",
    "MEMORY.md",
    "MAP.md",
    "LEDGER.md",
    "LEDGER",
    "TRANSLATION_MAP.md",
    "TRANSLATION_LEDGER.md",
    ".codex",
    "runs",
)
    !ispath(joinpath(ROOT, forbidden_path)) ||
        fail("development-only path is present: $(forbidden_path)")
end

println("BPA EMTP reference package check passed")
