using Test
using AIMORACatalogs

@testset "open equipment catalogs" begin
    entries = AIMORACatalogs.available_assets()
    @test length(entries) == 3
    @test length(unique(entry.id for entry in entries)) == length(entries)
    @test all(entry -> !isempty(entry.provenance), entries)
    @test all(entry -> !isempty(entry.licence), entries)
    @test all(entry -> isfile(AIMORACatalogs.asset_path(entry.id)), entries)

    transformer = AIMORACatalogs.asset(:generic_transformer_10mva)
    @test AIMORACatalogs.study_tabs(transformer) == [:emt, :power_flow, :short_circuit]
    @test AIMORACatalogs.study_facet(transformer, :power_flow).parameters[:reactance_pu] == 0.08
    @test_throws KeyError AIMORACatalogs.study_facet(transformer, :arc_flash)

    converter = AIMORACatalogs.asset(:generic_three_phase_two_level_vsc_50kva)
    @test converter.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(converter) == [:emt]
    @test converter.common[:parameter_status] == "synthetic_generic_exact_case_input"
    @test converter.common[:uncertainty_kind] == "not_statistical"
    converter_emt = AIMORACatalogs.study_facet(converter, :emt).parameters
    @test converter_emt[:fidelity] == "SwitchingDetailed"
    @test converter_emt[:control_family] ==
        "known-angle synchronous-reference-frame grid-following current PI"
    @test converter_emt[:modulation] ==
        "minimum_maximum_zero_sequence_injected_pwm_centered_space_vector_equivalent_line_voltage"
    @test converter_emt[:timestep_s] == 1.0e-6
    @test "phase_locked_loop_dynamics" in converter_emt[:unsupported_phenomena]
    @test "standard_conformance_or_certification" in
        converter_emt[:unsupported_phenomena]
end
