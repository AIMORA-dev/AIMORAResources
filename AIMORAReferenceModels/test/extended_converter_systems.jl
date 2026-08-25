@testset "independent extended converter equations" begin
    @test independent_dcdc_conversion_ratio(:buck, 0.4) == 0.4
    @test independent_dcdc_conversion_ratio(:boost, 0.4) ≈ 5 / 3
    @test independent_dcdc_conversion_ratio(:inverting_buck_boost, 0.4) ≈ -2 / 3
    power = independent_dual_active_bridge_power(
        800.0,
        400.0,
        1.0,
        pi / 6,
        2pi * 10_000.0,
        50.0e-6,
    )
    @test power > 0.0
    @test independent_dual_active_bridge_power(
        800.0,
        400.0,
        1.0,
        -pi / 6,
        2pi * 10_000.0,
        50.0e-6,
    ) ≈ -power
    @test independent_controlled_rectifier_average_voltage(1, 100.0, 0.0) ≈ 200 / pi
    @test independent_controlled_rectifier_average_voltage(3, 400.0, 0.0) ≈
        1200sqrt(2.0) / pi
    @test independent_interleaved_carrier_phases(4) ≈ [0.0, pi / 2, pi, 3pi / 2]
    connection = Bool[1 0 0; 0 0 1; 0 1 0]
    mapped = independent_matrix_converter_map(
        connection,
        [100.0, -40.0, -60.0],
        [2.0, -1.0, -1.0],
    )
    @test mapped.output_voltage_v == [100.0, -60.0, -40.0]
    @test mapped.input_current_a == [2.0, -1.0, -1.0]
    @test independent_converter_energy_residual(100.0, 80.0, 5.0, 15.0) == 0.0
end


@testset "independent converter modulation" begin
    @test independent_converter_triangular_carrier(0.0, 1_000.0) == 0.0
    @test independent_converter_triangular_carrier(0.5e-3, 1_000.0) == 1.0
    residual = independent_selective_harmonic_residual([0.2, 0.5, 0.8], 0.9, [5, 7])
    @test length(residual) == 3
    @test all(isfinite, residual)
    nearest = independent_nearest_level_state(0.62, 5)
    @test nearest.level == 3
    @test nearest.state == Int8[1, 1, 1, 0, 0]
    @test independent_dab_gate_state(0.0, 10_000.0, pi / 2) ==
        BitVector((true, false, false, true, false, true, true, false))
    @test independent_dab_gate_state(
        0.0,
        10_000.0,
        pi / 2;
        modulation=:dual_phase_shift,
        primary_inner_phase_shift_rad=pi / 2,
    ) == BitVector((true, false, false, true, false, true, true, false))
    @test independent_dab_gate_state(0.5 / 10_000.0, 10_000.0, pi / 2)[1:4] ==
        BitVector((false, true, true, false))
    @test independent_dab_gate_state(100 * 0.5e-6, 10_000.0, pi / 2)[1:4] ==
        BitVector((false, true, true, false))
end

@testset "independent matrix-converter switching-vector trace" begin
    first = independent_matrix_space_vector_state(
        [0.0, -sqrt(3.0) * 50.0, sqrt(3.0) * 50.0],
        0.0,
        30.0,
        10_000.0,
        0.75,
    )
    @test size(first.connection) == (3, 3)
    @test all(sum(first.connection; dims=2) .== 1)
    @test first.switching_vector_rank in 1:4
    trace = independent_switching_matrix_converter_trace(
        input_phase_voltage_peak_v=100.0,
        input_frequency_hz=50.0,
        output_frequency_hz=30.0,
        carrier_frequency_hz=10_000.0,
        modulation_index=0.75,
        source_resistance_ohm=0.1,
        load_resistance_ohm=5.0,
        load_inductance_h=2.0e-3,
        stop_time_s=0.2e-3,
        fixed_step_s=0.25e-6,
    )
    @test length(trace.time_s) == 801
    @test all(sum(trace.requested_connection; dims=2) .== 1)
    @test all(sum(trace.applied_connection; dims=2) .== 1)
    @test maximum(trace.commutation_stage) <= 5
    @test maximum(abs, vec(sum(trace.output_phase_current_a; dims=1))) <= 1.0e-12
    @test maximum(abs, trace.energy_residual_j) <= 2.0e-5
    replay = independent_switching_matrix_converter_trace(
        input_phase_voltage_peak_v=100.0,
        input_frequency_hz=50.0,
        output_frequency_hz=30.0,
        carrier_frequency_hz=10_000.0,
        modulation_index=0.75,
        source_resistance_ohm=0.1,
        load_resistance_ohm=5.0,
        load_inductance_h=2.0e-3,
        stop_time_s=0.2e-3,
        fixed_step_s=0.25e-6,
    )
    @test trace.output_phase_current_a == replay.output_phase_current_a
    @test trace.applied_connection == replay.applied_connection
end


@testset "independent line-commutated cycloconverter trace" begin
    for phase_count in (1, 3)
        trace = independent_switching_cycloconverter_trace(
            phase_count=phase_count,
            input_phase_voltage_peak_v=100.0,
            input_frequency_hz=50.0,
            output_frequency_hz=20.0,
            modulation_index=0.8,
            source_resistance_ohm=0.1,
            load_resistance_ohm=5.0,
            load_inductance_h=2.0e-3,
            output_phase_rad=0.02,
            stop_time_s=1.0e-3,
            fixed_step_s=10.0e-6,
        )
        @test length(trace.time_s) == 101
        @test size(trace.output_current_a) == (phase_count, 101)
        @test all(value -> value in (-1, 0, 1), trace.active_bridge_group)
        @test maximum(abs, trace.energy_residual_j) <= 1.0e-10
        @test maximum(abs, trace.output_current_a) > 0.0
        replay = independent_switching_cycloconverter_trace(
            phase_count=phase_count,
            input_phase_voltage_peak_v=100.0,
            input_frequency_hz=50.0,
            output_frequency_hz=20.0,
            modulation_index=0.8,
            source_resistance_ohm=0.1,
            load_resistance_ohm=5.0,
            load_inductance_h=2.0e-3,
            output_phase_rad=0.02,
            stop_time_s=1.0e-3,
            fixed_step_s=10.0e-6,
        )
        @test trace.output_current_a == replay.output_current_a
        @test trace.active_bridge_group == replay.active_bridge_group
    end
end

@testset "independent average converter-application trace" begin
    parameters = (
        grid_peak=325.0,
        grid_frequency=50.0,
        load_fundamental_peak=10.0,
        load_fifth_peak=2.0,
        load_seventh_peak=1.0,
        load_phase_shift=0.2,
        filter_resistance=0.1,
        filter_inductance=2.0e-3,
        dc_capacitance=5.0e-3,
        dc_reference=800.0,
        current_gain=20.0,
        integral_gain=2_000.0,
        dc_gain=0.01,
        modulation_limit=0.95,
        reference_loss=0.08e-3,
        reference_restore=0.14e-3,
        fixed_step=10.0e-6,
    )
    trace = independent_average_converter_application_trace(
        application=:shunt_active_filter,
        parameters=parameters,
        initial_state=[0.0, 0.0, 0.0, 800.0, 0.0, 0.0, 0.0],
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    replay = independent_average_converter_application_trace(
        application=:shunt_active_filter,
        parameters=parameters,
        initial_state=[0.0, 0.0, 0.0, 800.0, 0.0, 0.0, 0.0],
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    @test size(trace.state) == (7, 21)
    @test all(isfinite, trace.input_current_a)
    @test maximum(abs, trace.input_current_a) > 0.0
    @test maximum(abs, trace.energy_residual_w) <= 1.0e-2
    @test replay.state == trace.state
    @test trace.operating_mode[9] === :reference_loss_operation
    @test trace.operating_mode[15] === :restored_operation

    dvr_parameters = (
        source_peak=325.0,
        source_frequency=50.0,
        sag_start=0.1e-3,
        sag_stop=0.3e-3,
        sag_retained=0.6,
        bypass_start=0.15e-3,
        bypass_stop=0.25e-3,
        target_peak=325.0,
        load_resistance=20.0,
        load_inductance=10.0e-3,
        dc_capacitance=10.0e-3,
        dc_reference=800.0,
        injection_gain=1.0,
        transformer_ratio=1.0,
        modulation_limit=0.95,
        fixed_step=10.0e-6,
    )
    dvr = independent_average_converter_application_trace(
        application=:dynamic_voltage_restorer,
        parameters=dvr_parameters,
        initial_state=[0.0, 0.0, 0.0, 800.0],
        stop_time_s=0.4e-3,
        fixed_step_s=10.0e-6,
    )
    sag_sample = round(Int, dvr_parameters.sag_start / 10.0e-6) + 1
    clear_sample = round(Int, dvr_parameters.sag_stop / 10.0e-6) + 1
    balanced_peak_norm = sqrt(3.0 / 2.0) * dvr_parameters.source_peak
    @test sqrt(sum(abs2, dvr.input_voltage_v[:, sag_sample])) ≈
        dvr_parameters.sag_retained * balanced_peak_norm rtol=1.0e-13
    @test sqrt(sum(abs2, dvr.input_voltage_v[:, clear_sample])) ≈
        balanced_peak_norm rtol=1.0e-13
end

@testset "independent dual-active-bridge piecewise state-space trace" begin
    forward = independent_dual_active_bridge_trace(
        primary_dc_voltage_v=100.0,
        secondary_dc_voltage_v=80.0,
        transformer_ratio=1.0,
        leakage_resistance_ohm=0.02,
        leakage_inductance_h=50.0e-6,
        switching_frequency_hz=10_000.0,
        phase_shift_rad=pi / 2,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
    )
    reverse = independent_dual_active_bridge_trace(
        primary_dc_voltage_v=100.0,
        secondary_dc_voltage_v=80.0,
        transformer_ratio=1.0,
        leakage_resistance_ohm=0.02,
        leakage_inductance_h=50.0e-6,
        switching_frequency_hz=10_000.0,
        phase_shift_rad=-pi / 2,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
    )
    @test length(forward.time_s) == 201
    @test size(forward.primary_gate_state) == (4, 201)
    @test sum(forward.primary_dc_current_a) > 0.0
    @test sum(forward.secondary_dc_current_a) < 0.0
    @test sum(reverse.primary_dc_current_a) < 0.0
    @test sum(reverse.secondary_dc_current_a) > 0.0
    @test maximum(abs, forward.energy_residual_j) <= 1.0e-13
    @test maximum(abs, reverse.energy_residual_j) <= 1.0e-13
    @test forward.dissipated_energy_j[end] > 0.0
    @test reverse.dissipated_energy_j[end] > 0.0
end

@testset "independent average buck state-space trace" begin
    reference = independent_average_buck_trace(
        input_voltage_v=100.0,
        duty=0.5,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=0.0,
        initial_output_voltage_v=0.0,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 201
    @test reference.time_s[end] == 2.0e-3
    @test reference.inductor_current_a[2] > 0.0
    @test reference.output_voltage_v[2] > 0.0
    @test all(==(100.0), reference.input_voltage_v)
    @test reference.dissipated_energy_j[end] > 0.0
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-10
    @test all(isfinite, reference.energy_residual_w)
    @test all(>=(0.0), reference.stored_energy_j)
end

@testset "independent average boost state-space trace" begin
    reference = independent_average_boost_trace(
        input_voltage_v=100.0,
        duty=0.5,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=0.0,
        initial_output_voltage_v=0.0,
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 21
    @test reference.inductor_current_a[end] > 0.0
    @test reference.output_voltage_v[end] > 0.0
    @test all(==(100.0), reference.input_voltage_v)
    @test reference.input_current_a == reference.inductor_current_a
    @test all(>=(0.0), reference.stored_energy_j)
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-12
    @test maximum(abs, reference.energy_residual_w) <= 1.0e-10
end

@testset "independent average inverting buck-boost state-space trace" begin
    reference = independent_average_inverting_buck_boost_trace(
        input_voltage_v=100.0,
        duty=0.5,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=0.0,
        initial_output_voltage_v=0.0,
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 21
    @test reference.inductor_current_a[end] > 0.0
    @test reference.output_voltage_v[end] < 0.0
    @test all(==(100.0), reference.input_voltage_v)
    @test reference.input_current_a == 0.5 .* reference.inductor_current_a
    @test all(>=(0.0), reference.stored_energy_j)
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-12
    @test maximum(abs, reference.energy_residual_w) <= 1.0e-10
end

@testset "independent average four-quadrant state-space trace" begin
    positive = independent_average_four_quadrant_trace(
        input_voltage_v=100.0,
        duty=0.6,
        source_resistance_ohm=0.1,
        load_resistance_ohm=1.0,
        load_inductance_h=1.0e-3,
        initial_load_current_a=0.0,
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    negative = independent_average_four_quadrant_trace(
        input_voltage_v=100.0,
        duty=0.4,
        source_resistance_ohm=0.1,
        load_resistance_ohm=1.0,
        load_inductance_h=1.0e-3,
        initial_load_current_a=0.0,
        stop_time_s=0.2e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(positive.time_s) == 21
    @test positive.load_current_a[end] > 0.0
    @test negative.load_current_a[end] < 0.0
    @test negative.load_current_a == -positive.load_current_a
    @test negative.output_voltage_v == -positive.output_voltage_v
    @test maximum(abs, positive.circuit_residual_v) <= 1.0e-12
    @test maximum(abs, positive.energy_residual_w) <= 1.0e-12
end


@testset "independent switching buck state-space trace" begin
    reference = independent_switching_buck_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=1_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=5.0,
        initial_output_voltage_v=50.0,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 201
    @test reference.time_s[end] == 2.0e-3
    @test any(reference.gate_state)
    @test any(.!reference.gate_state)
    @test maximum(reference.switch_node_voltage_v) > 90.0
    @test minimum(reference.switch_node_voltage_v) == 0.0
    @test maximum(reference.output_voltage_v) > minimum(reference.output_voltage_v)
    @test all(isfinite, reference.inductor_current_a)
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-10

    blocked = independent_switching_buck_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=1_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=5.0,
        initial_output_voltage_v=50.0,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
        block_intervals_s=((0.2e-3, 0.8e-3),),
    )
    @test blocked.blocked_state[21:80] == trues(60)
    @test !blocked.blocked_state[20]
    @test !blocked.blocked_state[81]
    @test all(.!blocked.gate_state[blocked.blocked_state])
    @test blocked.gate_state[20]
    @test blocked.gate_state[81]
    @test maximum(abs, blocked.kcl_residual_a) <= 1.0e-10
    @test_throws ArgumentError independent_switching_buck_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=1_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=5.0,
        initial_output_voltage_v=50.0,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
        block_intervals_s=((0.205e-3, 0.8e-3),),
    )
end

@testset "independent switching boost state-space trace" begin
    reference = independent_switching_boost_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=1_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=1.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=37.03703703703703,
        initial_output_voltage_v=185.18518518518516,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 201
    @test reference.time_s[end] == 2.0e-3
    @test any(reference.gate_state)
    @test any(.!reference.gate_state)
    @test maximum(reference.switch_node_voltage_v) > 100.0
    @test minimum(reference.switch_node_voltage_v) == 0.0
    @test minimum(reference.inductor_current_a) > 0.0
    @test all(isfinite, reference.output_voltage_v)
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-12
end

@testset "independent switching inverting buck-boost state-space trace" begin
    reference = independent_switching_inverting_buck_boost_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=1_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=0.1,
        inductance_h=5.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_inductor_current_a=18.867924528301884,
        initial_output_voltage_v=-94.33962264150942,
        stop_time_s=2.0e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(reference.time_s) == 201
    @test reference.time_s[end] == 2.0e-3
    @test any(reference.gate_state)
    @test any(.!reference.gate_state)
    @test maximum(reference.switch_node_voltage_v) > 90.0
    @test minimum(reference.switch_node_voltage_v) < -80.0
    @test minimum(reference.inductor_current_a) > 0.0
    @test all(<(0.0), reference.output_voltage_v)
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-12
end

@testset "independent average dual-active-bridge fundamental transfer" begin
    reference = independent_average_dual_active_bridge_trace(
        primary_dc_voltage_v=100.0,
        secondary_dc_voltage_v=80.0,
        primary_source_resistance_ohm=0.01,
        secondary_source_resistance_ohm=0.01,
        transformer_ratio=1.0,
        switching_frequency_hz=10_000.0,
        phase_shift_rad=pi / 2,
        leakage_inductance_h=50.0e-6,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
    )
    @test length(reference.time_s) == 201
    @test all(>(0.0), reference.transferred_power_w)
    @test all(>(0.0), reference.primary_dc_current_a)
    @test all(<(0.0), reference.secondary_dc_current_a)
    @test maximum(abs, reference.energy_residual_w) <= 1.0e-10
    @test issorted(reference.source_dissipated_energy_j)
end

@testset "independent switching four-quadrant state-space trace" begin
    reference = independent_switching_four_quadrant_trace(
        input_voltage_v=100.0,
        duty=0.6,
        carrier_frequency_hz=10_000.0,
        source_resistance_ohm=0.1,
        load_resistance_ohm=1.0,
        load_inductance_h=1.0e-3,
        initial_load_current_a=5.0,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
    )
    @test length(reference.time_s) == 201
    @test reference.time_s[end] == 0.1e-3
    @test any(reference.positive_command)
    @test any(.!reference.positive_command)
    @test maximum(reference.output_voltage_v) > 90.0
    @test minimum(reference.output_voltage_v) < -90.0
    @test any(<(0.0), reference.input_current_a)
    @test all(>(0.0), reference.load_current_a)
    @test all(>=(0.0), reference.stored_energy_j)
    @test maximum(abs, reference.circuit_residual_v) <= 1.0e-12

    dead_time_reference = independent_switching_four_quadrant_trace(
        input_voltage_v=100.0,
        duty=0.6,
        carrier_frequency_hz=10_000.0,
        source_resistance_ohm=0.1,
        load_resistance_ohm=1.0,
        load_inductance_h=1.0e-3,
        initial_load_current_a=5.0,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
        dead_time_s=0.5e-6,
    )
    rising_command_sample = only(findall(
        diff(Int.(dead_time_reference.positive_command)) .== 1,
    )) + 1
    @test dead_time_reference.output_voltage_v[rising_command_sample] < 0.0
    @test dead_time_reference.output_voltage_v[rising_command_sample + 1] > 0.0
end

@testset "independent switching three-level T-type ideal limit" begin
    reference = independent_switching_three_level_t_type_trace(
        input_voltage_v=100.0,
        modulation_index=0.8,
        fundamental_frequency_hz=50.0,
        carrier_frequency_hz=10_000.0,
        source_resistance_ohm=0.05,
        dc_link_capacitance_f=2.0e-3,
        load_resistance_ohm=5.0,
        load_inductance_h=2.0e-3,
        initial_phase_current_a=(0.0, 0.0, 0.0),
        initial_upper_dc_link_voltage_v=50.0,
        initial_lower_dc_link_voltage_v=50.0,
        stop_time_s=0.1e-3,
        fixed_step_s=1.0e-6,
        dead_time_s=1.0e-6,
    )
    @test reference isa IndependentSwitchingThreeLevelTTypeTrace
    @test size(reference.requested_gate_state) == (12, 101)
    for sample in axes(reference.requested_level, 2), phase in 1:3
        offset = 4 * (phase - 1)
        expected = reference.requested_level[phase, sample] == 1 ?
            Bool[1, 0, 0, 0] :
            reference.requested_level[phase, sample] == 0 ?
                Bool[0, 1, 1, 0] : Bool[0, 0, 0, 1]
        @test reference.requested_gate_state[(offset + 1):(offset + 4), sample] ==
            expected
    end
    @test maximum(reference.kcl_residual_a) <= 1.0e-12
end

@testset "independent switching flying-capacitor ideal limit" begin
    reference = independent_switching_flying_capacitor_trace(
        input_voltage_v=100.0,
        modulation_index=0.8,
        fundamental_frequency_hz=50.0,
        carrier_frequency_hz=50_000.0,
        source_resistance_ohm=0.05,
        flying_capacitance_f=2.0e-3,
        load_resistance_ohm=5.0,
        load_inductance_h=2.0e-3,
        initial_phase_current_a=(0.0, 0.0, 0.0),
        initial_flying_capacitor_voltage_v=(50.0, 50.0, 50.0),
        stop_time_s=0.1e-3,
        fixed_step_s=0.25e-6,
        dead_time_s=0.25e-6,
    )
    @test reference isa IndependentSwitchingFlyingCapacitorTrace
    @test size(reference.requested_gate_state) == (12, 401)
    @test size(reference.flying_capacitor_voltage_v) == (3, 401)
    @test all(isfinite, reference.phase_voltage_v)
    @test all(isfinite, reference.phase_current_a)
    @test all(>(0.0), reference.flying_capacitor_voltage_v)
    @test maximum(reference.kcl_residual_a) <= 1.0e-12
    @test all(sample -> all(phase -> count(
        reference.requested_gate_state[(4 * (phase - 1) + 1):(4 * phase), sample],
    ) == 2, 1:3), axes(reference.requested_gate_state, 2))
    @test all(value -> value in Int8[-2, -1, 1, 2], reference.effective_state)
    @test any(==(Int8(1)), reference.effective_state)
    @test any(==(Int8(-1)), reference.effective_state)
    @test maximum(abs, reference.flying_capacitor_voltage_v .- 50.0) < 0.1
end

@testset "independent switching cascaded H-bridge ideal limit" begin
    reference = independent_switching_cascaded_h_bridge_trace(
        cell_dc_capacitance_f=2.0e-3,
        modulation=:phase_shifted_carrier,
        modulation_index=0.8,
        fundamental_frequency_hz=50.0,
        carrier_frequency_hz=50_000.0,
        load_resistance_ohm=5.0,
        load_inductance_h=2.0e-3,
        initial_phase_current_a=(0.0, 0.0, 0.0),
        initial_cell_dc_voltage_v=fill(50.0, 3, 2),
        stop_time_s=0.1e-3,
        fixed_step_s=0.25e-6,
        dead_time_s=0.25e-6,
    )
    @test reference isa IndependentSwitchingCascadedHBridgeTrace
    @test size(reference.requested_cell_state) == (3, 2, 401)
    @test size(reference.requested_gate_state) == (24, 401)
    @test size(reference.cell_dc_voltage_v) == (3, 2, 401)
    @test all(isfinite, reference.phase_voltage_v)
    @test all(isfinite, reference.phase_current_a)
    @test all(>(0.0), reference.cell_dc_voltage_v)
    @test maximum(reference.kcl_residual_a) <= 1.0e-12
    @test all(sample -> all(cell -> count(identity,
        reference.requested_gate_state[(4 * (cell - 1) + 1):(4 * cell), sample],
    ) == 2, 1:6), axes(reference.requested_gate_state, 2))
    @test all(value -> value in Int8[-1, 0, 1], reference.requested_cell_state)
    @test any(==(Int8(1)), reference.requested_cell_state)
    @test any(==(Int8(-1)), reference.requested_cell_state)
    @test reference.stored_energy_j[end] < reference.stored_energy_j[1]
end

@testset "independent switching interleaved-chopper state-space trace" begin
    reference = independent_switching_interleaved_chopper_trace(
        input_voltage_v=100.0,
        duty=0.5,
        carrier_frequency_hz=10_000.0,
        source_resistance_ohm=0.1,
        inductor_resistance_ohm=fill(0.1, 2),
        inductance_h=fill(1.0e-3, 2),
        capacitance_f=100.0e-6,
        load_resistance_ohm=10.0,
        initial_channel_inductor_current_a=fill(2.5, 2),
        initial_output_voltage_v=50.0,
        stop_time_s=0.1e-3,
        fixed_step_s=0.5e-6,
    )
    @test length(reference.time_s) == 201
    @test size(reference.gate_state) == (2, 201)
    @test all(channel -> any(reference.gate_state[channel, :]) &&
        any(.!reference.gate_state[channel, :]), 1:2)
    @test all(>(0.0), reference.channel_inductor_current_a)
    @test all(>(0.0), reference.output_voltage_v)
    aggregate_current = vec(sum(reference.channel_inductor_current_a; dims=1))
    aggregate_ripple = maximum(aggregate_current) - minimum(aggregate_current)
    channel_ripple = maximum(
        maximum(reference.channel_inductor_current_a[channel, :]) -
            minimum(reference.channel_inductor_current_a[channel, :])
        for channel in 1:2
    )
    @test aggregate_ripple < channel_ripple
    @test maximum(abs, reference.kcl_residual_a) <= 1.0e-12
end
