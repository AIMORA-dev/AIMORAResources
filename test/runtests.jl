using Test
using AIMORACatalogs

@testset "open equipment catalogs" begin
    entries = AIMORACatalogs.available_assets()
    @test length(entries) == 2
    @test length(unique(entry.id for entry in entries)) == length(entries)
    @test all(entry -> !isempty(entry.provenance), entries)
    @test all(entry -> !isempty(entry.licence), entries)
    @test all(entry -> isfile(AIMORACatalogs.asset_path(entry.id)), entries)

    transformer = AIMORACatalogs.asset(:generic_transformer_10mva)
    @test AIMORACatalogs.study_tabs(transformer) == [:emt, :power_flow, :short_circuit]
    @test AIMORACatalogs.study_facet(transformer, :power_flow).parameters[:reactance_pu] == 0.08
    @test_throws KeyError AIMORACatalogs.study_facet(transformer, :arc_flash)
end
