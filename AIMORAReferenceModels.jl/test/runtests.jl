using Test
using AIMORAReferenceModels

include("wideband_line_parameters.jl")

@testset "independent extended semiconductor formulations" begin
    recovery = independent_recovered_charge_backward_euler(
        2.0e-6,
        -1.0,
        2.0e-6,
        1.0e-6,
    )
    @test recovery.accepted_charge_c ≈ 2.0e-6 / 3.0
    @test abs(recovery.balance_residual_a) <= 4.0e-16
    for voltage_v in (-20.0, -1.0, 0.0, 10.0)
        perturbation_v = 1.0e-6
        derivative = (
            independent_junction_charge(2.0e-6, 10.0, 0.4, voltage_v + perturbation_v) -
            independent_junction_charge(2.0e-6, 10.0, 0.4, voltage_v - perturbation_v)
        ) / (2.0 * perturbation_v)
        @test derivative ≈ independent_junction_capacitance(
            2.0e-6,
            10.0,
            0.4,
            voltage_v,
        ) rtol=1.0e-7
        @test independent_junction_energy(2.0e-6, 10.0, 0.4, voltage_v) >= 0.0
    end
    @test independent_turn_off_tail(10.0, 2.0e-6, 2.0e-6) ≈ 10.0 / exp(1.0)
    @test independent_turn_off_tail(
        10.0,
        2.0e-6,
        20.0e-6;
        cutoff_current_a=1.0,
    ) == 0.0
    energy_values = reshape(Float64.(1:8), 2, 2, 2)
    @test independent_trilinear_semiconductor_energy(
        energy_values,
        [0.0, 1.0],
        [0.0, 1.0],
        [300.0, 400.0],
        1.0,
        1.0,
        400.0,
    ) == energy_values[2, 2, 2]
    thermal = independent_cauer_backward_euler(
        [1.0, 2.0],
        [0.5, 1.0],
        [300.0, 300.0],
        300.0,
        10.0,
        1.0,
    )
    @test all(temperature -> temperature >= 300.0, thermal.temperature_k)
    @test thermal.ambient_heat_flow_w >= 0.0
    @test thermal.stored_energy_j >= 0.0
end


@testset "independent extended VSC control and filter references" begin
    active = independent_vsc_current_projection(200.0, 100.0, 180.0, :active)
    @test active == (direct=180.0, quadrature=0.0, limited=true)
    reactive = independent_vsc_current_projection(200.0, 100.0, 180.0, :reactive)
    @test reactive.direct ≈ sqrt(180.0^2 - 100.0^2)
    @test hypot(reactive.direct, reactive.quadrature) ≈ 180.0
    magnitude = independent_vsc_current_projection(200.0, 100.0, 180.0, :magnitude)
    @test hypot(magnitude.direct, magnitude.quadrature) ≈ 180.0

    current = independent_vsc_power_current_reference(
        20.0e3,
        5.0e3,
        325.0,
        0.0,
        180.0,
        :active,
    )
    @test current.direct ≈ (2.0 / 3.0) * 20.0e3 / 325.0
    @test current.quadrature ≈ -(2.0 / 3.0) * 5.0e3 / 325.0

    pll = independent_vsc_pll_sample(
        0.0,
        0.0,
        325.0,
        3.25,
        50.0,
        110.0,
        4.0e3,
        20.0,
        45.0,
        65.0,
        50.0e-6,
    )
    @test pll.error ≈ 3.25 / hypot(325.0, 3.25)
    @test pll.locked

    resonator = independent_vsc_resonator_sample(
        0.0,
        0.0,
        2.0,
        2.0 * pi * 50.0,
        5,
        80.0,
        12.0,
        50.0e-6,
    )
    @test resonator.derivative_state > 0.0
    @test resonator.integral_state > 0.0
    @test independent_vsc_power_filter_sample(0.0, 100.0, 2.0e-3, 50.0e-6) ≈
        100.0 * (1.0 - exp(-50.0e-6 / 2.0e-3))

    droop = independent_vsc_droop_sample(0.0, 0.0, 10.0e3, 50.0, 3.0e-5, 50.0e-6)
    @test droop.frequency_rad_per_s ≈ 2.0 * pi * 50.0 + 3.0e-5 * 10.0e3
    swing = independent_vsc_swing_sample(
        0.0,
        2.0 * pi * 50.0,
        0.0,
        10.0e3,
        50.0,
        4.0,
        120.0,
        50.0e-6,
    )
    @test swing.acceleration_rad_per_s2 == 2500.0

    phase_voltage = [325.0, -162.5, -162.5]
    phase_current = [10.0, -5.0, -5.0]
    power = independent_vsc_instantaneous_power(phase_voltage, phase_current)
    @test power.active_w ≈ sum(phase_voltage .* phase_current)
    @test abs(power.reactive_var) <= 2.0e-12

    angles = range(0.0, 2.0 * pi; length=201)[1:end-1]
    samples = hcat(([
        325.0 * cos(angle),
        325.0 * cos(angle - 2.0 * pi / 3.0),
        325.0 * cos(angle + 2.0 * pi / 3.0),
    ] for angle in angles)...)
    sequence = independent_vsc_sequence_components(samples, angles)
    @test abs(sequence.positive) ≈ 325.0 atol=2.0e-12
    @test abs(sequence.negative) <= 2.0e-12
    @test abs(sequence.zero) <= 2.0e-12

    capacitance = 20.0e-6
    step = 1.0e-6
    previous_voltage = 100.0
    previous_current = 0.0
    voltage = 101.0
    current = 2.0 * capacitance * (voltage - previous_voltage) / step - previous_current
    @test independent_vsc_capacitor_companion_residual(
        previous_voltage,
        previous_current,
        voltage,
        current,
        capacitance,
        step,
    ) ≈ 0.5 * capacitance * (voltage - previous_voltage)^2
end
using LinearAlgebra

@testset "independent reference-model package boundary" begin
    @test nameof(AIMORAReferenceModels) === :AIMORAReferenceModels
end

@testset "independent exact multirate calendar dependency delay and hold" begin
    writer = IndependentTaskCalendarSpec(
        "writer",
        3,
        0 // 1,
        2 // 10,
        0 // 1,
        1 // 10;
        priority = 5,
        write_resources = ["command"],
    )
    reader = IndependentTaskCalendarSpec(
        "reader",
        1,
        0 // 1,
        4 // 10,
        0 // 1,
        0 // 1;
        priority = -5,
        read_resources = ["command"],
        write_resources = ["trip"],
        predecessors = ["writer"],
    )
    reference = independent_multirate_task_reference(
        [reader, writer];
        start = 0 // 1,
        stop = 1 // 1,
        initial_outputs = ["writer" => 0 // 1, "reader" => 0 // 1],
        sample_value = (specification, activation_index, held) ->
            specification.name == "writer" ? activation_index // 1 :
            held["writer"] + activation_index // 10,
    )
    @test reference.quantum == 1 // 10
    @test reference.execution_order == ["writer", "reader"]
    @test reference.activation_counts == ["reader" => 3, "writer" => 6]
    @test reference.release_counts == ["reader" => 3, "writer" => 5]
    @test Dict(reference.maximum_pending_depths) == Dict("reader" => 1, "writer" => 1)
    @test Dict(reference.held_outputs) == Dict("reader" => 43 // 10, "writer" => 5 // 1)
    zero_stages = [
        occurrence.stage for occurrence in reference.occurrences
        if occurrence.instant == 0 // 1
    ]
    @test zero_stages == [
        :read, :compute, :enqueue, :hold,
        :read, :compute, :enqueue, :write, :hold,
    ]
    @test occursin(r"^[0-9a-f]{64}$", reference.deterministic_signature_sha256)
    @test reference.deterministic_signature_sha256 == independent_multirate_task_reference(
        [reader, writer];
        start = 0 // 1,
        stop = 1 // 1,
        initial_outputs = ["writer" => 0 // 1, "reader" => 0 // 1],
        sample_value = (specification, activation_index, held) ->
            specification.name == "writer" ? activation_index // 1 :
            held["writer"] + activation_index // 10,
    ).deterministic_signature_sha256

    unordered_reader = IndependentTaskCalendarSpec(
        "reader",
        1,
        0 // 1,
        4 // 10,
        0 // 1,
        0 // 1;
        read_resources = ["command"],
    )
    @test_throws ArgumentError independent_multirate_task_reference(
        [writer, unordered_reader];
        start = 0 // 1,
        stop = 1 // 1,
    )
    @test_throws ArgumentError IndependentTaskCalendarSpec(
        "floating",
        8,
        0.0,
        0.1,
        0.0,
        0.0,
    )
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

@testset "independent native extension formulations" begin
    lag = sampled_saturating_lag_reference(0.1, 0.9, 2.0, 2.0e-3, 0.5e-3, -1.0, 1.0)
    expected_state = 0.9 + (0.1 - 0.9) * exp(-0.25)
    @test lag.state ≈ expected_state atol=2.0e-16
    @test lag.output ≈ 2.0 * expected_state atol=4.0 * eps(Float64)
    @test sampled_saturating_lag_reference(
        0.8,
        1.0,
        2.0,
        2.0e-3,
        0.5e-3,
        -1.0,
        1.0,
    ).output == 1.0
    @test sampled_saturating_lag_reference(
        lag.state,
        0.9,
        2.0,
        2.0e-3,
        0.5e-3,
        -1.0,
        1.0,
    ).state ≈ sampled_saturating_lag_reference(
        0.1,
        0.9,
        2.0,
        2.0e-3,
        1.0e-3,
        -1.0,
        1.0,
    ).state atol=2.0e-16
    @test_throws ArgumentError sampled_saturating_lag_reference(
        0.0,
        1.0,
        1.0,
        0.0,
        1.0e-3,
        -1.0,
        1.0,
    )

    cubic = passive_cubic_branch_reference(1.5, -0.25, 0.2, 0.03)
    voltage = 1.75
    @test cubic.positive_current_a ≈ 0.2 * voltage + 0.03 * voltage^3 atol=2.0e-16
    @test cubic.negative_current_a == -cubic.positive_current_a
    @test cubic.derivative_s == 0.2 + 3.0 * 0.03 * voltage^2
    @test cubic.absorbed_power_w >= 0.0
    @test cubic.terminal_kcl_residual_a == 0.0
    perturbation = 1.0e-6
    forward = passive_cubic_branch_reference(1.5 + perturbation, -0.25, 0.2, 0.03)
    backward = passive_cubic_branch_reference(1.5 - perturbation, -0.25, 0.2, 0.03)
    @test (forward.positive_current_a - backward.positive_current_a) /
          (2.0 * perturbation) ≈ cubic.derivative_s rtol=2.0e-10
    swapped = passive_cubic_branch_reference(-0.25, 1.5, 0.2, 0.03)
    @test swapped.positive_current_a == -cubic.positive_current_a
    @test_throws ArgumentError passive_cubic_branch_reference(1.0, 0.0, -0.1, 0.0)

    rl = series_rl_trapezoidal_reference(0.5, 1.0, 4.0, 2.0, 10.0e-3, 100.0e-6)
    @test rl.conductance_s == inv(2.0 + 2.0 * 10.0e-3 / 100.0e-6)
    @test abs(rl.constitutive_residual_v) <= 2.0e-14
    @test rl.stored_energy_j >= 0.0
    @test rl.dissipated_power_w >= 0.0
    @test_throws ArgumentError series_rl_trapezoidal_reference(
        0.0,
        0.0,
        1.0,
        1.0,
        0.0,
        1.0e-4,
    )

    @test directed_linear_event_root_reference(
        0.0,
        1.0e-3,
        -0.25,
        0.75;
        direction=:rising,
    ) == 0.25e-3
    @test directed_linear_event_root_reference(
        0.0,
        1.0e-3,
        0.75,
        -0.25;
        direction=:falling,
    ) == 0.75e-3
    @test_throws ArgumentError directed_linear_event_root_reference(
        0.0,
        1.0e-3,
        0.25,
        0.75;
        direction=:rising,
    )
end

@testset "independent consistent EMT initialization references" begin
    physical_frequency_hz = 50.0
    timestep_s = 500.0e-6
    physical_angular_frequency = 2.0 * pi * physical_frequency_hz
    matched_angular_frequency = trapezoidal_reactive_angular_frequency(
        physical_frequency_hz,
        timestep_s,
    )
    @test matched_angular_frequency ≈
        2.0 / timestep_s * tan(pi * physical_frequency_hz * timestep_s)
    @test matched_angular_frequency > physical_angular_frequency
    @test_throws ArgumentError trapezoidal_reactive_angular_frequency(
        1.0 / (2.0 * timestep_s),
        timestep_s,
    )

    branches = [
        (from_node=1, to_node=2, resistance_ohm=2.0, inductance_h=10.0e-3),
        (from_node=2, to_node=3, resistance_ohm=4.0, inductance_h=20.0e-3),
    ]
    shunts = [(node=3, conductance_s=0.1)]
    sources = [(node=1, conductance_s=5.0, voltage_phasor_v=100.0 - 15.0im)]
    physical = independent_series_rl_network_equilibrium(
        3,
        branches,
        shunts,
        sources;
        physical_frequency_hz,
    )
    matched = independent_series_rl_network_equilibrium(
        3,
        branches,
        shunts,
        sources;
        physical_frequency_hz,
        timestep_s,
    )
    @test physical.classification === :unique
    @test matched.classification === :unique
    @test physical.numerical_rank == 3
    @test physical.maximum_residual_a <= 2.0e-13
    @test physical.admittance_symmetry_max_abs_error == 0.0
    @test physical.minimum_dissipative_eigenvalue_s >= -2.0e-16
    @test norm(physical.node_voltage_phasors - matched.node_voltage_phasors) > 1.0e-4
    @test maximum(abs, independent_series_rl_recurrence_residuals(
        matched.node_voltage_phasors,
        branches;
        physical_frequency_hz,
        timestep_s,
    )) <= 2.0e-14
    @test abs(independent_lumped_companion_recurrence_residual(
        :series_rl,
        90.0 - 30.0im;
        resistance_ohm=2.0,
        inductance_h=10.0e-3,
        physical_frequency_hz,
        timestep_s,
    )) <= 2.0e-14
    @test abs(independent_lumped_companion_recurrence_residual(
        :series_rlc,
        90.0 - 30.0im;
        resistance_ohm=2.0,
        inductance_h=10.0e-3,
        capacitance_f=2.0e-3,
        physical_frequency_hz,
        timestep_s,
    )) <= 2.0e-14
    @test abs(independent_lumped_companion_recurrence_residual(
        :capacitor,
        90.0 - 30.0im;
        capacitance_f=2.0e-3,
        physical_frequency_hz,
        timestep_s,
    )) <= 8.0e-14
    coupled_recurrence = independent_coupled_series_rl_recurrence_residuals(
        ComplexF64[90.0 - 30.0im, -45.0 + 20.0im],
        [2.0 0.1; 0.1 2.5],
        [10.0e-3 1.0e-3; 1.0e-3 12.0e-3];
        physical_frequency_hz,
        timestep_s,
    )
    @test maximum(abs, coupled_recurrence) <= 3.0e-14

    shifted = independent_series_rl_network_equilibrium(
        3,
        branches,
        shunts,
        sources;
        physical_frequency_hz,
        timestep_s,
        time_origin_s=1.25e-3,
    )
    expected_rotation = cis(2.0 * pi * physical_frequency_hz * 1.25e-3)
    @test shifted.node_voltage_phasors ≈
        matched.node_voltage_phasors .* expected_rotation atol=2.0e-14
    @test independent_peak_phasor_samples(
        2.0 - 3.0im,
        physical_frequency_hz,
        (0.0, timestep_s),
    ) ≈ [
        2.0,
        real((2.0 - 3.0im) * cis(physical_angular_frequency * timestep_s)),
    ] atol=2.0e-15
    periodic_times = [0.0, timestep_s, 2.0 * timestep_s]
    periodic_phasors = ComplexF64[2.0 - 3.0im, -1.0 + 0.5im]
    periodic_frequencies = [50.0, 60.0]
    periodic_trace = Float64[
        real(periodic_phasors[node] * cis(2.0 * pi * periodic_frequencies[node] * time))
        for node in eachindex(periodic_phasors), time in periodic_times
    ]
    periodic_error = independent_periodic_voltage_error(
        periodic_phasors,
        periodic_frequencies,
        periodic_times,
        periodic_trace,
    )
    @test periodic_error.maximum_absolute_error_v == 0.0
    @test periodic_error.normalized_rms == 0.0
    @test_throws DimensionMismatch independent_periodic_voltage_error(
        periodic_phasors,
        periodic_frequencies,
        periodic_times,
        zeros(3, 3),
    )

    mapping = independent_operating_point_mapping(
        2.0 - 3.0im,
        -2000.0 + 3000.0im;
        scale_to_target=1000.0,
        orientation_sign=-1.0,
    )
    @test mapping.mapped_value == -2000.0 + 3000.0im
    @test mapping.residual == 0.0

    islanded = independent_series_rl_network_equilibrium(
        2,
        [(from_node=1, to_node=2, resistance_ohm=1.0, inductance_h=0.0)],
        NamedTuple[],
        NamedTuple[];
        physical_frequency_hz,
    )
    @test islanded.classification === :islanded
    @test islanded.numerical_rank == 1
    @test islanded.unreferenced_components == [[1, 2]]
    @test isempty(islanded.node_voltage_phasors)

    ill_conditioned = independent_series_rl_network_equilibrium(
        2,
        [(from_node=1, to_node=2, resistance_ohm=1.0, inductance_h=0.0)],
        [(node=1, conductance_s=1.0e-13)],
        NamedTuple[];
        physical_frequency_hz,
    )
    @test ill_conditioned.classification === :ill_conditioned
    @test ill_conditioned.numerical_rank == 2
    @test ill_conditioned.condition_estimate > 1.0e12
    @test isempty(ill_conditioned.node_voltage_phasors)

    nonunique = AIMORAReferenceModels._independent_dense_harmonic_solution(
        ComplexF64[1.0 1.0; 1.0 1.0],
        ComplexF64[2.0, 2.0];
        absolute_current_tolerance_a=1.0e-12,
        relative_current_tolerance=1.0e-10,
        rank_threshold_multiplier=10.0,
        maximum_condition_estimate=1.0e12,
    )
    @test nonunique.classification === :nonunique
    @test isempty(nonunique.unreferenced_components)
    @test isempty(nonunique.node_voltage_phasors)

    infeasible = AIMORAReferenceModels._independent_dense_harmonic_solution(
        ComplexF64[1.0 -1.0; -1.0 1.0],
        ComplexF64[1.0, 1.0];
        absolute_current_tolerance_a=1.0e-12,
        relative_current_tolerance=1.0e-10,
        rank_threshold_multiplier=10.0,
        maximum_condition_estimate=1.0e12,
    )
    @test infeasible.classification === :infeasible
    @test infeasible.maximum_residual_a > 0.5
    @test isempty(infeasible.node_voltage_phasors)
end
