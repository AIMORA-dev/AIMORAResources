using Test
using AIMORACatalogs

@testset "open equipment catalogs" begin
    entries = AIMORACatalogs.available_assets()
    @test length(entries) == 17
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

    semiconductor = AIMORACatalogs.asset(:generic_extended_semiconductor_commutation)
    @test semiconductor.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(semiconductor) == [:emt]
    semiconductor_emt = AIMORACatalogs.study_facet(semiconductor, :emt).parameters
    @test semiconductor_emt[:fidelity] == "SwitchingDetailed"
    @test semiconductor_emt[:recovered_charge_lifetime_s] == 5.0e-6
    @test semiconductor_emt[:junction_grading_exponent] == 0.45
    @test "manufacturer_prediction" in semiconductor_emt[:unsupported_phenomena]

    bridge_library = AIMORACatalogs.asset(:generic_bridge_topology_library)
    @test bridge_library.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(bridge_library) == [:emt]
    bridge_emt = AIMORACatalogs.study_facet(bridge_library, :emt).parameters
    @test bridge_emt[:fidelity] == "SwitchingDetailed"
    @test bridge_emt[:topology_schema] == "aimora_bridge_topology_v1"
    @test bridge_emt[:public_case_topology_count] == 11
    @test bridge_emt[:public_case_valve_position_count] == 52
    @test "flying_capacitor_leg" in bridge_emt[:families]
    @test "arbitrary_topology_synthesis" in bridge_emt[:unsupported_phenomena]

    extended_vsc = AIMORACatalogs.asset(:extended_vsc_control_filter_platform)
    @test extended_vsc.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(extended_vsc) == [:emt]
    extended_vsc_emt = AIMORACatalogs.study_facet(extended_vsc, :emt).parameters
    @test extended_vsc_emt[:fidelity] == "SwitchingDetailed"
    @test extended_vsc_emt[:supported_combination_count] == 24
    @test extended_vsc_emt[:public_case_count] == 4
    @test "virtual_synchronous_grid_forming" in
        extended_vsc_emt[:controller_families]
    @test "lcl" in extended_vsc_emt[:filter_families]
    @test "atp_or_pscad_equivalence" in
        extended_vsc_emt[:unsupported_phenomena]

    line_parameters = AIMORACatalogs.asset(:generic_wideband_line_parameter_inputs)
    @test line_parameters.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(line_parameters) == [:line_parameters]
    line_facet = AIMORACatalogs.study_facet(line_parameters, :line_parameters).parameters
    @test line_facet[:frequency_domain_hz] == [0.1, 1.0e6]
    @test line_facet[:maximum_soil_layers] == 4
    @test line_facet[:route_kinds] == ["overhead", "cable", "mixed"]
    @test "time_domain_line_realization" in line_facet[:unsupported_phenomena]

    line_fitting = AIMORACatalogs.asset(:generic_coupled_line_fitting_passivity)
    @test AIMORACatalogs.study_tabs(line_fitting) == [:line_fitting]
    fitting_facet = AIMORACatalogs.study_facet(line_fitting, :line_fitting).parameters
    @test fitting_facet[:candidate_pole_orders] == [20, 40, 60, 80]
    @test fitting_facet[:continuous_passivity_certificate] ==
        "bounded_real_hamiltonian"
    @test "emt_line_history_execution" in fitting_facet[:unsupported_phenomena]

    line_runtime = AIMORACatalogs.asset(:generic_coupled_line_runtime)
    @test AIMORACatalogs.study_tabs(line_runtime) == [:emt]
    runtime_facet = AIMORACatalogs.study_facet(line_runtime, :emt).parameters
    @test runtime_facet[:default_timestep_s] == 1.0e-5
    @test runtime_facet[:initialization] ==
        "exact_discrete_sinusoidal_operating_point"
    @test runtime_facet[:mixed_route_policy] ==
        "separately_executed_uniform_segments_with_explicit_node_mapping"
    @test runtime_facet[:uncertainty_execution] ==
        "every_exact_declared_fit_through_identical_timestep_initialization_events_outputs_and_restart"
    @test line_runtime.common[:declared_soil_resistivity_alternative_ohm_m] == 110.0
    @test line_runtime.common[:unknown_uncertainty_explicit]
    @test !line_runtime.common[:uncertainty_set_complete]
    @test "ulm_file_compatibility" in runtime_facet[:unsupported_phenomena]

    transformer_tier_ids = (
        :generic_transformer_low_frequency_terminal,
        :generic_transformer_bctran_terminal,
        :generic_transformer_hybrid,
        :generic_transformer_magnetic_equivalent,
        :generic_transformer_wideband_black_box,
        :generic_transformer_grey_box_ladder,
        :generic_transformer_white_box_winding,
    )
    transformer_tiers = AIMORACatalogs.asset.(transformer_tier_ids)
    @test getfield.(transformer_tiers, :manufacturer) == ntuple(_ -> nothing, 7)
    @test all(
        entry -> AIMORACatalogs.study_tabs(entry) == [:emt],
        transformer_tiers,
    )
    @test getindex.(getfield.(transformer_tiers, :common), :public_case) == (
        "emt_transformer_low_frequency",
        "emt_transformer_bctran",
        "emt_transformer_hybrid",
        "emt_transformer_magnetic_equivalent",
        "emt_transformer_wideband_black_box",
        "emt_transformer_grey_box",
        "emt_transformer_white_box",
    )
    @test getindex.(getfield.(transformer_tiers, :common), :timestep_s) ==
        ntuple(_ -> 1.0e-5, 7)
    @test all(transformer_tiers) do entry
        common = entry.common
        emt = AIMORACatalogs.study_facet(entry, :emt).parameters
        common[:parameter_status] == "synthetic_generic_exact_case_input" &&
            common[:terminal_current_orientation] == "positive_into_apparatus" &&
            length(common[:parameter_natures]) == 3 &&
            startswith(emt[:restart], "exact_") &&
            "atp_or_pscad_equivalence" in emt[:unsupported_phenomena] &&
            "certification" in emt[:unsupported_phenomena]
    end

    machines = AIMORACatalogs.asset(:generic_modern_machine_families)
    @test machines.manufacturer === nothing
    @test AIMORACatalogs.study_tabs(machines) == [:emt]
    @test length(machines.common[:families]) == 6
    @test length(machines.common[:public_cases]) == 7
    @test machines.common[:terminal_order] == ["a", "b", "c", "neutral"]
    machine_emt = AIMORACatalogs.study_facet(machines, :emt).parameters
    @test machine_emt[:fidelity] == "field_coupled_detailed"
    @test "atp_or_pscad_equivalence" in machine_emt[:unsupported_phenomena]
    @test AIMORACatalogs.study_facet(
        AIMORACatalogs.asset(:generic_transformer_wideband_black_box),
        :emt,
    ).parameters[:port_count] == 12
    @test AIMORACatalogs.study_facet(
        AIMORACatalogs.asset(:generic_transformer_grey_box_ladder),
        :emt,
    ).parameters[:represented_node_count] == 32
    @test AIMORACatalogs.study_facet(
        AIMORACatalogs.asset(:generic_transformer_white_box_winding),
        :emt,
    ).parameters[:section_count_per_winding] == 8
end
