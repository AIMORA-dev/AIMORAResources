using Test
using TOML

const REPOSITORY_ROOT = normpath(joinpath(@__DIR__, ".."))

@testset "report template library boundary" begin
    manifest = TOML.parsefile(joinpath(REPOSITORY_ROOT, "template-manifest.toml"))

    @test manifest["schema"] == "aimora-report-template-library-v1"
    @test manifest["licence"] == "PolyForm-Noncommercial-1.0.0"
    @test isempty(manifest["template_ids"])
end
