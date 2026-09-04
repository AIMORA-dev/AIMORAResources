using TOML

@testset "native equipment collections and reusable assemblies" begin
    document = AIMORACatalogs.equipment_library_document()
    @test document["schema"] == "aimora-equipment-library-v1"
    @test document["version"] == "1.0.0"
    @test [item["scope"] for item in document["collection"]] ==
          ["system", "user", "project"]
    @test [item["mutable"] for item in document["collection"]] ==
          [false, true, true]
    @test length(document["equipment"]) == 14
    @test length(document["assembly"]) == 2
    @test Set(item["category"] for item in document["equipment"]) == Set((
        "transformer",
        "current_transformer",
        "voltage_transformer",
        "switching",
        "cable",
        "bus",
        "load",
        "grounding",
        "machine",
        "converter",
        "storage",
        "source",
        "annotation",
    ))

    symbol_manifest = TOML.parsefile(normpath(joinpath(
        @__DIR__,
        "..",
        "..",
        "symbol-collections",
        "manifest.toml",
    )))
    system_symbols = Set(only(filter(
        item -> item["scope"] == "system",
        symbol_manifest["collection"],
    ))["symbols"])
    @test all(item["symbol_id"] in system_symbols for item in document["equipment"])

    native = AIMORACatalogs.native_equipment_library_document()
    @test native["source_owner"] == "AIMORAResources/AIMORACatalogs"
    @test length(native["entries"]) == 16
    @test Dict(item["scope"] => item["count"] for item in native["collections"]) ==
          Dict("system" => 16, "user" => 0, "project" => 0)
    feeder = only(filter(
        item -> item["id"] ==
                "aimora://catalog/system/assembly.feeder_bay@1.0.0",
        native["entries"],
    ))
    @test feeder["kind"] == "assembly"
    @test feeder["member_count"] == 6
    @test length(feeder["parts"]) == 6
end
