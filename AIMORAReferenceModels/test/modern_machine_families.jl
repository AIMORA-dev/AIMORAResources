using LinearAlgebra

@testset "independent modern machine formulations" begin
    angle = 0.43
    transform = independent_machine_phase_transform(angle)
    @test transform * transpose(transform) ≈ Matrix{Float64}(I, 3, 3) atol=2.0e-15
    phase_voltage = [120.0, -40.0, 25.0]
    phase_current = [3.0, -1.0, 0.25]
    @test dot(phase_voltage, phase_current) ≈
        dot(transform * phase_voltage, transform * phase_current) atol=2.0e-13

    inductance = [
        0.02 0.0 0.0 0.0 0.0
        0.0 0.10 0.08 0.0 0.0
        0.0 0.08 0.11 0.0 0.0
        0.0 0.0 0.0 0.09 0.07
        0.0 0.0 0.0 0.07 0.10
    ]
    inverse_inductance = inv(inductance)
    offset = zeros(5)
    flux = [0.0, 0.08, 0.05, -0.04, -0.02]
    coenergy = independent_machine_coenergy(
        flux,
        inverse_inductance,
        offset;
        d_axis_index=2,
        q_axis_index=4,
        radial_coefficient_per_wb2_h=0.03,
        cross_coefficient_per_wb2_h=0.02,
    )
    @test coenergy.current_flux_jacobian_per_h ≈
        transpose(coenergy.current_flux_jacobian_per_h) atol=1.0e-14
    @test coenergy.cross_derivative_per_h ==
        coenergy.reciprocal_cross_derivative_per_h
    @test minimum(eigvals(Symmetric(coenergy.current_flux_jacobian_per_h))) > 0.0
    epsilon = 1.0e-7
    for column in eachindex(flux)
        plus = copy(flux)
        minus = copy(flux)
        plus[column] += epsilon
        minus[column] -= epsilon
        plus_current = independent_machine_coenergy(
            plus,
            inverse_inductance,
            offset;
            d_axis_index=2,
            q_axis_index=4,
            radial_coefficient_per_wb2_h=0.03,
            cross_coefficient_per_wb2_h=0.02,
        ).current_a
        minus_current = independent_machine_coenergy(
            minus,
            inverse_inductance,
            offset;
            d_axis_index=2,
            q_axis_index=4,
            radial_coefficient_per_wb2_h=0.03,
            cross_coefficient_per_wb2_h=0.02,
        ).current_a
        @test (plus_current - minus_current) / (2.0 * epsilon) ≈
            coenergy.current_flux_jacobian_per_h[:, column] rtol=2.0e-7 atol=2.0e-7
    end

    previous_terminal = zeros(4)
    terminal = [100.0, -50.0, -50.0, 0.0]
    state = independent_machine_trapezoidal_step(
        zeros(5),
        previous_terminal,
        terminal,
        inverse_inductance,
        offset,
        [0.2, 0.2, 0.4, 0.2, 0.4],
        zeros(5);
        zero_index=1,
        d_axis_index=2,
        q_axis_index=4,
        electrical_angle_rad=0.0,
        mechanical_speed_rad_s=2.0 * pi * 60.0 / 2.0,
        pole_pairs=2,
        timestep_s=1.0e-5,
        radial_coefficient_per_wb2_h=0.03,
        cross_coefficient_per_wb2_h=0.02,
        tolerance=1.0e-13,
    )
    @test state.residual_wb <= 1.0e-12
    @test abs(sum(state.terminal_current_a)) <= 1.0e-12
    @test maximum(abs, sum(state.terminal_jacobian_s; dims=1)) <= 1.0e-12
    @test state.copper_loss_w >= 0.0
    @test isfinite(state.electromagnetic_torque_nm)

    incidence = [1.0 -1.0 0.0; 0.0 1.0 -1.0]
    shaft = independent_machine_shaft_step(
        zeros(3),
        fill(100.0, 3),
        [2.0, 3.0, 4.0],
        [0.1, 0.2, 0.3],
        incidence,
        [1000.0, 1200.0],
        [1.0, 1.5],
        zeros(2),
        [10.0, 0.0, -5.0],
        1.0e-4,
    )
    @test shaft.kinetic_energy_j > 0.0
    @test shaft.elastic_energy_j >= 0.0
    @test shaft.damping_loss_w >= 0.0
    @test abs(shaft.angular_momentum_residual_nms) <= 1.0e-10

    family_matrices = independent_machine_family_matrices(
        :cage_induction,
        (
            stator_resistance_ohm=0.2,
            zero_sequence_inductance_h=0.01,
            stator_d_leakage_inductance_h=0.005,
            stator_q_leakage_inductance_h=0.006,
            d_axis_magnetizing_inductance_h=0.08,
            q_axis_magnetizing_inductance_h=0.07,
            field_resistance_ohm=0.0,
            field_leakage_inductance_h=0.0,
            d_damper_resistance_ohm=0.0,
            d_damper_leakage_inductance_h=0.0,
            q_damper_resistance_ohm=0.0,
            q_damper_leakage_inductance_h=0.0,
            permanent_magnet_flux_wb=0.0,
        ),
        [(resistance_ohm=0.15, leakage_inductance_h=0.004)],
    )
    @test size(family_matrices.inductance_h) == (5, 5)
    @test family_matrices.inductance_h ≈ transpose(family_matrices.inductance_h)
    @test minimum(eigvals(Symmetric(family_matrices.inductance_h))) > 0.0

    target_current = [0.1, -0.2, 0.05, 0.3, -0.1]
    consistent = independent_machine_consistent_flux(
        target_current,
        family_matrices.inverse_inductance_per_h,
        family_matrices.permanent_flux_offset_wb;
        d_axis_index=family_matrices.d_axis_index,
        q_axis_index=family_matrices.q_axis_index,
        radial_coefficient_per_wb2_h=0.03,
        cross_coefficient_per_wb2_h=0.02,
    )
    @test consistent.residual_a <= 1.0e-12
    @test independent_machine_coenergy(
        consistent.flux_wb,
        family_matrices.inverse_inductance_per_h,
        family_matrices.permanent_flux_offset_wb;
        d_axis_index=family_matrices.d_axis_index,
        q_axis_index=family_matrices.q_axis_index,
        radial_coefficient_per_wb2_h=0.03,
        cross_coefficient_per_wb2_h=0.02,
    ).current_a ≈ target_current atol=1.0e-12

    control_previous = IndependentMachineControlState(
        0.0,
        100.0,
        5.0,
        10.0,
        0.0,
        0.0,
        5.0,
        10.0,
        false,
        false,
    )
    control = independent_machine_control_step(
        control_previous,
        [100.0, -50.0, -50.0, 0.0],
        101.0,
        1.0e-3,
        (
            base_field_voltage_v=5.0,
            base_mechanical_torque_nm=10.0,
            voltage_reference_v=100.0,
            excitation_gain=0.1,
            excitation_time_constant_s=0.02,
            field_voltage_min_v=0.0,
            field_voltage_max_v=20.0,
            speed_reference_rad_s=100.0,
            governor_droop_rad_s_per_nm=0.1,
            governor_time_constant_s=0.04,
            torque_min_nm=-20.0,
            torque_max_nm=20.0,
            stabilizer_gain=0.01,
            stabilizer_washout_s=0.1,
            stabilizer_lead_s=0.02,
            stabilizer_lag_s=0.05,
        ),
    )
    @test all(isfinite, (
        control.sensed_voltage_v,
        control.field_voltage_v,
        control.mechanical_torque_nm,
        control.stabilizer_washout_state,
    ))
    @test 0.0 <= control.field_voltage_v <= 20.0
    @test -20.0 <= control.mechanical_torque_nm <= 20.0

    balance = independent_machine_power_balance(
        terminal,
        state.terminal_current_a,
        0.0,
        0.0,
        zeros(2),
        zeros(2),
        10.0,
        100.0,
        0.01,
        0.001,
        1.0e-5,
    )
    @test isfinite(balance.energy_residual_j)
end
