using Test
using AIMORAReferenceModels
using LinearAlgebra

@testset "independent reference-model package boundary" begin
    @test nameof(AIMORAReferenceModels) === :AIMORAReferenceModels
end

@testset "independent three-phase transforms and PWM" begin
    angle = 0.37
    phase = [310.0, -122.0, -188.0]
    synchronous = phase_to_synchronous_reference(phase, angle)
    @test synchronous_to_phase_reference(synchronous, angle) ≈ phase atol = 2.0e-13
    @test amplitude_invariant_clarke_matrix() * [1.0, 1.0, 1.0] ≈ [0.0, 0.0, 1.0] atol = 2.0e-16
    @test synchronous_reference_rotation_matrix(angle) *
          transpose(synchronous_reference_rotation_matrix(angle)) ≈ I atol = 2.0e-16

    sinusoidal = two_level_pwm_duties(
        (240.0, -120.0, -120.0),
        800.0;
        modulation = :sinusoidal,
    )
    injected = two_level_pwm_duties(
        (240.0, -120.0, -120.0),
        800.0;
        modulation = :centered_space_vector_equivalent,
    )
    @test collect(sinusoidal) ≈ [0.8, 0.35, 0.35] atol = 2.0e-16
    @test collect(injected) ≈ [0.725, 0.275, 0.275] atol = 2.0e-16
    @test [injected[1] - injected[2], injected[2] - injected[3]] ≈
        [sinusoidal[1] - sinusoidal[2], sinusoidal[2] - sinusoidal[3]] atol = 2.0e-16
    @test_throws ArgumentError two_level_pwm_duties(
        (1.0, 0.0, -1.0),
        800.0;
        modulation = :unsupported,
    )
end

@testset "independent synchronous current-controller formulation" begin
    phase_crest_v = sqrt(2.0 / 3.0) * 400.0
    reference = synchronous_current_control_reference(
        (phase_crest_v, -0.5 * phase_crest_v, -0.5 * phase_crest_v),
        (10.0, -5.0, -5.0),
        0.0,
        800.0;
        grid_line_line_rms_v = 400.0,
        active_power_reference_w = 10_000.0,
        reactive_power_reference_var = 0.0,
        current_limit_a = 180.0,
        control_period_s = 100.0e-6,
        series_resistance_ohm = 0.15,
        series_inductance_h = 2.3e-3,
        frequency_hz = 50.0,
        proportional_gain_v_per_a = 4.0,
        integral_gain_v_per_as = 600.0,
        minimum_duty = 0.02,
        maximum_duty = 0.98,
    )
    @test !reference.saturated
    @test reference.direct_current_a ≈ 10.0 atol = 2.0e-15
    @test reference.quadrature_current_a ≈ 0.0 atol = 2.0e-15
    @test reference.direct_integral_as > 0.0
    @test sum(reference.phase_voltage_reference_v) ≈ 0.0 atol = 2.0e-13
    @test all(duty -> 0.02 <= duty <= 0.98, reference.duties)

    saturated = synchronous_current_control_reference(
        (phase_crest_v, -0.5 * phase_crest_v, -0.5 * phase_crest_v),
        (0.0, 0.0, 0.0),
        0.0,
        650.0;
        grid_line_line_rms_v = 400.0,
        active_power_reference_w = 50_000.0,
        reactive_power_reference_var = 25_000.0,
        current_limit_a = 180.0,
        control_period_s = 100.0e-6,
        series_resistance_ohm = 0.15,
        series_inductance_h = 2.3e-3,
        frequency_hz = 50.0,
        proportional_gain_v_per_a = 4.0,
        integral_gain_v_per_as = 600.0,
        direct_integral_as = 0.1,
        quadrature_integral_as = -0.2,
    )
    @test saturated.saturated
    @test saturated.direct_integral_as == 0.1
    @test saturated.quadrature_integral_as == -0.2
end

@testset "exact piecewise-constant series R-L reconstruction" begin
    resistance = 0.15
    inductance = 2.3e-3
    interval = 10.0e-6
    voltage = 120.0
    initial = -4.0
    exact = series_rl_piecewise_constant_current(
        initial,
        voltage,
        resistance,
        inductance,
        interval,
    )
    @test exact ≈ voltage / resistance +
        (initial - voltage / resistance) * exp(-resistance * interval / inductance)
    trace = series_rl_piecewise_constant_trace(
        initial,
        fill(voltage, 100),
        resistance,
        inductance,
        interval,
    )
    @test length(trace) == 101
    @test trace[end] ≈ series_rl_piecewise_constant_current(
        initial,
        voltage,
        resistance,
        inductance,
        100 * interval,
    ) atol = 2.0e-12
    @test_throws ArgumentError series_rl_piecewise_constant_current(
        initial,
        voltage,
        resistance,
        0.0,
        interval,
    )
end

@testset "independent nonlinear scalar and manufactured MNA references" begin
    voltage = exponential_conductance_voltage_reference(
        1.0,
        0.55,
        0.01,
        0.2,
    )
    @test abs(0.55 * voltage + 0.01 * expm1(voltage / 0.2) - 1.0) <= 1.0e-13
    @test_throws ArgumentError exponential_conductance_voltage_reference(
        1.0,
        0.55,
        0.0,
        0.2,
    )

    manufactured = manufactured_cubic_constraint_case()
    @test maximum(abs, manufactured.residual) <= 2.0e-16
    @test manufactured.nonlinear_device_absorbed_power_w ≈ 0.3 atol=2.0e-16
    @test manufactured.ideal_constraint_absorbed_power_w ≈ 0.4 atol=2.0e-16
    @test abs(manufactured.algebraic_power_balance_residual_w) <=
        4.0 * eps(Float64)
    @test manufactured.jacobian == [1.5 -0.5 1.0; -0.5 1.5 -1.0; 1.0 -1.0 0.0]
    perturbation = 1.0e-7
    forward = cubic_mna_residual_jacobian_reference(
        manufactured.exact_voltage_v .+ [perturbation, 0.0],
        manufactured.exact_constraint_current_a,
        manufactured.linear_admittance_s,
        manufactured.source_current_a,
        manufactured.positive_node,
        manufactured.negative_node,
        manufactured.linear_conductance_s,
        manufactured.cubic_coefficient_a_per_v3,
        manufactured.constraint_coefficients,
        manufactured.constraint_value_v,
    )
    backward = cubic_mna_residual_jacobian_reference(
        manufactured.exact_voltage_v .- [perturbation, 0.0],
        manufactured.exact_constraint_current_a,
        manufactured.linear_admittance_s,
        manufactured.source_current_a,
        manufactured.positive_node,
        manufactured.negative_node,
        manufactured.linear_conductance_s,
        manufactured.cubic_coefficient_a_per_v3,
        manufactured.constraint_coefficients,
        manufactured.constraint_value_v,
    )
    central_column = (forward.residual - backward.residual) / (2.0 * perturbation)
    @test central_column ≈ manufactured.jacobian[:, 1] rtol=5.0e-9
end
