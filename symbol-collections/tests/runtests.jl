using Test
using TOML

const COLLECTION_ROOT = normpath(joinpath(@__DIR__, ".."))

@testset "public symbol collection contract" begin
    manifest = TOML.parsefile(joinpath(COLLECTION_ROOT, "manifest.toml"))
    @test manifest["schema"] == "aimora-symbol-collections-v1"
    @test manifest["grammar_owner"] == "AIMORAPlatform/AIMORASymbols"
    @test occursin(r"^[0-9a-f]{40}$", manifest["grammar_revision"])
    @test manifest["library_id"] == "aimora-public-symbols"
    @test manifest["licence"] == "PolyForm-Noncommercial-1.0.0"
    @test Set(manifest["search_fields"]) == Set(["id", "name", "asset_class", "accessibility"])

    collections = Dict(item["scope"] => item for item in manifest["collection"])
    @test Set(keys(collections)) == Set(["system", "user", "project"])
    @test !collections["system"]["mutable"]
    @test collections["user"]["mutable"]
    @test collections["project"]["mutable"]
    system_ids = Set(collections["system"]["symbols"])
    @test length(system_ids) == 20
    @test isempty(collections["user"]["symbols"])
    @test isempty(collections["project"]["symbols"])

    categories = manifest["category"]
    categorized_ids = Set(Iterators.flatten(category["symbols"] for category in categories))
    @test categorized_ids == system_ids
    @test sum(length(category["symbols"]) for category in categories) == length(system_ids)
end
