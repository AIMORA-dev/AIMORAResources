using LinearAlgebra

@testset "independent switched transformer terminal companion" begin
    apparatus_admittance_s = [3.0 -1.0; -1.0 2.0]
    apparatus_history_current_a = [0.4, -0.2]
    network_voltage_v = [10.0, -4.0]
    closed = independent_transformer_switched_terminal_companion(
        apparatus_admittance_s,
        apparatus_history_current_a,
        trues(2),
        Matrix{Float64}(I, 2, 2),
        zeros(2, 2),
        network_voltage_v,
    )
    @test closed.network_terminal_current_a ≈
        apparatus_admittance_s * network_voltage_v .+ apparatus_history_current_a
    @test closed.network_terminal_admittance_s == apparatus_admittance_s
    @test closed.conjugate_power_residual_w == 0.0

    one_open = independent_transformer_switched_terminal_companion(
        apparatus_admittance_s,
        apparatus_history_current_a,
        BitVector([true, false]),
        Diagonal([1.1, 1.0]),
        [0.5 -0.5; -0.5 0.5],
        network_voltage_v,
    )
    @test one_open.open_terminal_current_residual_a <= 2.0e-15
    @test one_open.apparatus_terminal_voltage_v[1] == 11.0
    @test one_open.network_terminal_admittance_s ≈
        transpose(one_open.network_terminal_admittance_s)
    @test abs(one_open.conjugate_power_residual_w) <= 2.0e-13

    all_open = independent_transformer_switched_terminal_companion(
        apparatus_admittance_s,
        apparatus_history_current_a,
        falses(2),
        Matrix{Float64}(I, 2, 2),
        zeros(2, 2),
        network_voltage_v,
    )
    @test all_open.network_terminal_current_a == zeros(2)
    @test all_open.network_terminal_admittance_s == zeros(2, 2)
    @test all_open.open_terminal_current_residual_a <= 2.0e-15
end

@testset "independent transformer connection and terminal energy" begin
    incidence = [
        1.0 0.0
        -1.0 1.0
        0.0 -1.0
    ]
    connection = independent_transformer_connection(
        incidence,
        [120.0, 30.0, -20.0],
        [2.0, -3.0],
    )
    @test connection.coil_voltage_v == [90.0, 50.0]
    @test connection.terminal_current_a == [2.0, -5.0, 3.0]
    @test connection.node_power_w == connection.coil_power_w == 30.0
    @test connection.power_residual_w == 0.0

    resistance = reshape([2.0], 1, 1)
    inductance = reshape([0.5], 1, 1)
    capacitance = reshape([2.0e-3], 1, 1)
    conductance = reshape([1.0e-2], 1, 1)
    accepted = IndependentTransformerTerminalState(1, 2)
    terminal = independent_transformer_terminal_step(
        resistance,
        inductance,
        capacitance,
        conductance,
        [1.0; -1.0;;],
        accepted,
        [5.0, -5.0],
        0.1,
    )
    coil_voltage = 10.0
    expected_coil_current = coil_voltage / (2.0 + 2.0 * 0.5 / 0.1)
    expected_capacitor_current = 2.0 * 2.0e-3 * coil_voltage / 0.1
    expected_total_current = expected_coil_current +
        expected_capacitor_current + 1.0e-2 * coil_voltage
    @test terminal.state.coil_current_a[1] ≈ expected_coil_current
    @test terminal.state.capacitor_current_a[1] ≈ expected_capacitor_current
    @test terminal.state.terminal_current_a ≈ [expected_total_current, -expected_total_current]
    @test terminal.terminal_jacobian_s ≈
        (inv(12.0) + 0.04 + 0.01) .* [1.0 -1.0; -1.0 1.0]
    @test abs(terminal.energy_residual_j) <= 2.0e-15
end

@testset "independent transformer dynamic core-loss companion" begin
    timestep_s = 2.0e-4
    previous_flux_density_t = 0.1
    current_flux_density_t = 0.13
    classical_coefficient = 0.02
    excess_coefficient = 0.05
    volume_m3 = 0.008
    result = independent_transformer_dynamic_core_loss_companion(
        previous_flux_density_t,
        current_flux_density_t,
        timestep_s,
        classical_coefficient,
        excess_coefficient;
        excess_rate_regularization_t_per_s=1.0e-3,
        core_volume_m3=volume_m3,
    )
    rate = (current_flux_density_t - previous_flux_density_t) / timestep_s
    @test result.flux_density_rate_t_per_s == rate
    @test result.endpoint_classical_field_a_per_m ==
        2.0 * classical_coefficient * rate
    @test result.endpoint_excess_field_a_per_m > 0.0
    @test result.classical_loss_energy_j ≈
        volume_m3 * timestep_s * classical_coefficient * rate^2
    @test result.excess_loss_energy_j > 0.0
    @test result.total_loss_energy_j ==
        result.classical_loss_energy_j + result.excess_loss_energy_j
    continuation = independent_transformer_dynamic_core_loss_companion(
        current_flux_density_t,
        current_flux_density_t + 0.01,
        timestep_s,
        classical_coefficient,
        excess_coefficient;
        previous_classical_field_a_per_m=result.endpoint_classical_field_a_per_m,
        previous_excess_field_a_per_m=result.endpoint_excess_field_a_per_m,
        excess_rate_regularization_t_per_s=1.0e-3,
        core_volume_m3=volume_m3,
    )
    @test 0.5 * (
        result.endpoint_classical_field_a_per_m +
        continuation.endpoint_classical_field_a_per_m
    ) ≈ continuation.midpoint_classical_field_a_per_m
    @test 0.5 * (
        result.endpoint_excess_field_a_per_m +
        continuation.endpoint_excess_field_a_per_m
    ) ≈ continuation.midpoint_excess_field_a_per_m
end

@testset "independent transformer magnetic graph endpoints" begin
    magnetic_incidence = [1.0 -1.0]
    winding_turns = reshape([10.0, 20.0], 2, 1)
    linear = independent_transformer_magnetic_linear_response(
        magnetic_incidence,
        winding_turns,
        [100.0, 200.0],
        [3.0],
    )
    @test linear.branch_flux_wb ≈ [0.3, 0.3]
    @test linear.branch_mmf_drop_at ≈ [30.0, 60.0]
    @test linear.winding_flux_linkage_wb_turn ≈ [9.0]
    @test linear.stored_energy_j ≈ 13.5
    @test linear.continuity_residual_wb <= 2.0e-16
    @test linear.constitutive_residual_at <= 2.0e-14

    nonlinear = independent_transformer_piecewise_magnetic_endpoint(
        magnetic_incidence,
        winding_turns,
        [1.0, 1.0],
        [1.0, 1.0],
        [0.0, 0.0],
        [[-2.0, 0.0, 2.0], [-2.0, 0.0, 2.0]],
        [[-200.0, 0.0, 200.0], [-400.0, 0.0, 400.0]],
        [3.0],
    )
    @test nonlinear.branch_flux_wb ≈ linear.branch_flux_wb atol=2.0e-14
    @test nonlinear.branch_mmf_drop_at ≈ linear.branch_mmf_drop_at atol=2.0e-12
    @test nonlinear.differential_reluctance_at_per_wb ≈ [100.0, 200.0]
    @test nonlinear.continuity_residual_wb <= 2.0e-16
    @test nonlinear.constitutive_residual_at <= 2.0e-13

    gapped_uniform = independent_transformer_piecewise_magnetic_endpoint(
        magnetic_incidence,
        reshape([100.0, 0.0], 2, 1),
        [0.8, 0.8],
        [0.01, 0.01],
        [2.0e-3, 0.0],
        [[0.0, 0.5, 1.5, 2.0], [0.0, 0.5, 1.5, 2.0]],
        [[0.0, 100.0, 2_000.0, 10_000.0], [0.0, 100.0, 2_000.0, 10_000.0]],
        [0.25],
    )
    gapped_with_fringe = independent_transformer_piecewise_magnetic_endpoint(
        magnetic_incidence,
        reshape([100.0, 0.0], 2, 1),
        [0.8, 0.8],
        [0.01, 0.01],
        [2.0e-3, 0.0],
        [[0.0, 0.5, 1.5, 2.0], [0.0, 0.5, 1.5, 2.0]],
        [[0.0, 100.0, 2_000.0, 10_000.0], [0.0, 100.0, 2_000.0, 10_000.0]],
        [0.25];
        branch_air_gap_effective_area_factor=[1.2, 1.0],
    )
    @test gapped_with_fringe.branch_flux_wb[1] > gapped_uniform.branch_flux_wb[1]
    @test gapped_with_fringe.continuity_residual_wb <= 2.0e-16
    @test gapped_with_fringe.constitutive_residual_at <= 2.0e-12
end

@testset "independent transformer certified wideband balance" begin
    accepted = IndependentTransformerWidebandState(1, 1)
    result = independent_transformer_wideband_step(
        reshape([-2.0], 1, 1),
        reshape([1.0], 1, 1),
        reshape([1.0], 1, 1),
        reshape([0.5], 1, 1),
        reshape([1.0], 1, 1),
        reshape([4.0], 1, 1),
        accepted,
        [2.0],
        0.1,
    )
    expected_state = 1.0 / 11.0
    @test result.state.rational_state ≈ [expected_state]
    @test result.state.terminal_current_a ≈ [1.0 + expected_state]
    @test result.terminal_jacobian_s ≈ reshape([0.5 + 1.0 / 22.0], 1, 1)
    @test result.state.stored_energy_j ≈ 0.5 * expected_state^2
    @test result.state.dissipated_energy_j >= 0.0
    @test abs(result.energy_residual_j) <= 2.0e-17
end

@testset "independent transformer condensed network KCL" begin
    accepted = IndependentTransformerNetworkState(3, [1, 1])
    result = independent_transformer_network_step(
        [
            reshape([1.0, -1.0, 0.0], 3, 1),
            reshape([0.0, 1.0, -1.0], 3, 1),
        ],
        [reshape([1.0], 1, 1), reshape([1.0], 1, 1)],
        [reshape([0.0], 1, 1), reshape([0.0], 1, 1)],
        zeros(3, 3),
        zeros(3, 3),
        [1, 3],
        accepted,
        [1.0, 0.0],
        0.1,
    )
    @test result.state.represented_node_voltage_v ≈ [1.0, 0.5, 0.0]
    @test result.terminal_current_a ≈ [0.5, -0.5]
    @test result.terminal_jacobian_s ≈ [0.5 -0.5; -0.5 0.5]
    @test result.internal_kcl_residual_a <= 2.0e-16
end

@testset "independent Tellinen trajectory and reversal" begin
    field_grid = [-100.0, 0.0, 100.0]
    lower_flux = [-2.0, -1.0, 0.0]
    upper_flux = [0.0, 1.0, 2.0]
    accepted = independent_tellinen_state(field_grid, lower_flux, upper_flux)
    increasing = independent_tellinen_trial(
        field_grid,
        lower_flux,
        upper_flux,
        accepted,
        0.2;
        maximum_field_increment_a_per_m=0.25,
    )
    @test increasing.state.flux_density_t == 0.2
    @test increasing.state.field_strength_a_per_m > 0.0
    @test increasing.state.direction == 1
    @test increasing.state.reversal_count == 0
    @test abs(increasing.residual_t) <= 1.0e-10
    @test increasing.differential_reluctivity_m_per_h > 0.0

    decreasing = independent_tellinen_trial(
        field_grid,
        lower_flux,
        upper_flux,
        increasing.state,
        -0.1;
        maximum_field_increment_a_per_m=0.25,
    )
    @test decreasing.state.flux_density_t == -0.1
    @test decreasing.state.field_strength_a_per_m < increasing.state.field_strength_a_per_m
    @test decreasing.state.direction == -1
    @test decreasing.state.reversal_count == 1
    @test abs(decreasing.residual_t) <= 1.0e-10
end

@testset "independent transformer sinusoidal and residual-flux initialization" begin
    frequency_hz = 60.0
    timestep_s = 10.0e-6
    physical_frequency = 2.0 * pi * frequency_hz
    next_rotation = cis(physical_frequency * timestep_s)
    terminal_voltage_phasor = ComplexF64[10.0 + 2.0im, -4.0 + 1.0im]
    resistance = [0.4 0.0; 0.0 0.5]
    inductance = [0.12 0.02; 0.02 0.10]
    capacitance = [2.0e-9 0.0; 0.0 1.0e-9]
    conductance = [1.0e-7 0.0; 0.0 2.0e-7]
    incidence = Matrix{Float64}(I, 2, 2)
    terminal = independent_transformer_sinusoidal_terminal_state(
        resistance,
        inductance,
        capacitance,
        conductance,
        incidence,
        terminal_voltage_phasor,
        frequency_hz,
        timestep_s,
    )
    @test terminal.electrical_residual_v <= 1.0e-13
    accepted = IndependentTransformerTerminalState(
        real.(terminal.coil_current_phasor),
        real.(terminal.capacitor_current_phasor),
        real.(terminal.coil_voltage_phasor),
        real.(terminal_voltage_phasor),
        real.(terminal.terminal_current_phasor),
        0.0,
        0.0,
        0.0,
        0.5 * dot(
            real.(terminal.coil_current_phasor),
            inductance * real.(terminal.coil_current_phasor),
        ),
        0.5 * dot(
            real.(terminal.coil_voltage_phasor),
            capacitance * real.(terminal.coil_voltage_phasor),
        ),
        0,
    )
    next_terminal = independent_transformer_terminal_step(
        resistance,
        inductance,
        capacitance,
        conductance,
        incidence,
        accepted,
        real.(terminal_voltage_phasor .* next_rotation),
        timestep_s,
    )
    @test next_terminal.state.coil_current_a ≈
        real.(terminal.coil_current_phasor .* next_rotation) rtol=1.0e-11
    @test next_terminal.state.capacitor_current_a ≈
        real.(terminal.capacitor_current_phasor .* next_rotation) rtol=1.0e-11

    linear_state = independent_transformer_sinusoidal_linear_state(
        -1_000.0 .* Matrix{Float64}(I, 2, 2),
        Matrix{Float64}(I, 2, 2),
        terminal_voltage_phasor,
        frequency_hz,
        timestep_s,
    )
    @test linear_state.residual <= 1.0e-13
    @test all(isfinite, linear_state.state)

    branch_incidence = (
        reshape([1.0, -1.0, 0.0], 3, 1),
        reshape([0.0, 1.0, -1.0], 3, 1),
    )
    branch_resistance = (reshape([0.2], 1, 1), reshape([0.3], 1, 1))
    branch_inductance = (reshape([2.0e-3], 1, 1), reshape([3.0e-3], 1, 1))
    network_capacitance = Matrix(Diagonal([1.0e-9, 2.0e-9, 1.0e-9]))
    network_conductance = Matrix(Diagonal([1.0e-7, 2.0e-7, 1.0e-7]))
    network = independent_transformer_sinusoidal_network_state(
        branch_incidence,
        branch_resistance,
        branch_inductance,
        network_capacitance,
        network_conductance,
        [1, 3],
        terminal_voltage_phasor,
        frequency_hz,
        timestep_s,
    )
    @test network.internal_kcl_residual_a <= 1.0e-12
    accepted_network = IndependentTransformerNetworkState(
        real.(network.represented_node_voltage_phasor),
        [real.(value) for value in network.branch_current_phasor],
        [real.(value) for value in network.branch_voltage_phasor],
        real.(network.capacitor_current_phasor),
    )
    next_network = independent_transformer_network_step(
        branch_incidence,
        branch_resistance,
        branch_inductance,
        network_capacitance,
        network_conductance,
        [1, 3],
        accepted_network,
        real.(terminal_voltage_phasor .* next_rotation),
        timestep_s,
    )
    @test next_network.state.represented_node_voltage_v ≈
        real.(network.represented_node_voltage_phasor .* next_rotation) rtol=1.0e-10
    @test next_network.state.branch_current_a[1] ≈
        real.(network.branch_current_phasor[1] .* next_rotation) rtol=1.0e-10
    @test next_network.internal_kcl_residual_a <= 1.0e-12

    residual = independent_transformer_residual_flux_equilibrium(
        [1.0 -1.0],
        [100.0 0.0; 0.0 100.0],
        [1.0e-3, 1.0e-3],
        [0.0, 0.0],
        [0.0, 0.0];
        projection_tolerance_wb=1.0e-12,
    )
    @test residual.projected_branch_flux_wb == [1.0e-3, 1.0e-3]
    @test residual.projection_correction_wb == 0.0
    @test residual.continuity_residual_wb == 0.0
    @test residual.constitutive_residual_at == 0.0
    @test_throws DomainError independent_transformer_residual_flux_equilibrium(
        [1.0 -1.0],
        [100.0 0.0; 0.0 100.0],
        [1.0e-3, -1.0e-3],
        [0.0, 0.0],
        [0.0, 0.0];
        projection_tolerance_wb=0.0,
    )
end
