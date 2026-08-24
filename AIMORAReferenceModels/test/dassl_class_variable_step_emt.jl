@testset "independent DASSL-class passive RLC formulation" begin
    uniform_expected = (
        [1.0, -1.0],
        [3.0 / 2.0, -2.0, 1.0 / 2.0],
        [11.0 / 6.0, -3.0, 3.0 / 2.0, -1.0 / 3.0],
        [25.0 / 12.0, -4.0, 3.0, -4.0 / 3.0, 1.0 / 4.0],
        [137.0 / 60.0, -5.0, 5.0, -10.0 / 3.0, 5.0 / 4.0, -1.0 / 5.0],
    )
    # A binary-exact step isolates the uniform-grid coefficient identity. The
    # polynomial moment checks below still exercise the weights at their actual
    # floating-point nodes rather than treating rounded decimal nodes as exact.
    step_s = 0.125
    for order in 1:5
        nodes = [1.0 - index * step_s for index in 0:order]
        weights = independent_bdf_derivative_weights(nodes)
        @test weights ≈ uniform_expected[order] ./ step_s atol=3.0e-13
        for degree in 0:order
            expected = degree == 0 ? 0.0 : degree * nodes[1]^(degree - 1)
            @test dot(weights, nodes .^ degree) ≈ expected atol=2.0e-12
        end
    end

    parameters = IndependentPassiveRLCDAEParameters(
        source_voltage_v=120.0,
        source_resistance_ohm=0.8,
        inductance_h=15.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=24.0,
    )
    initial_state = [0.0, 0.0]
    initial_derivative = independent_passive_rlc_initial_derivative(
        parameters,
        initial_state,
    )
    @test independent_passive_rlc_dae_residual(
        parameters,
        initial_state,
        initial_derivative,
    ) ≈ zeros(2) atol=1.0e-14

    exact = independent_passive_rlc_exact_state(
        parameters,
        1.0e-3,
        initial_state,
    )
    exact_derivative = independent_passive_rlc_initial_derivative(parameters, exact)
    energy = independent_passive_rlc_energy_balance(
        parameters,
        exact,
        exact_derivative,
    )
    @test energy.stored_energy_j >= 0.0
    @test energy.source_resistive_loss_w >= 0.0
    @test energy.load_loss_w >= 0.0
    @test abs(energy.balance_residual_w) <= 2.0e-12

    errors = Float64[]
    for step in (2.0e-4, 1.0e-4, 5.0e-5)
        times = Float64[0.0]
        states = reshape(copy(initial_state), :, 1)
        while times[end] < 1.0e-3 - eps(1.0e-3)
            next_time = min(times[end] + step, 1.0e-3)
            history_count = min(2, length(times))
            reference = independent_passive_rlc_bdf_step(
                parameters,
                next_time,
                @view(times[(end - history_count + 1):end]),
                @view(states[:, (end - history_count + 1):end]),
            )
            @test maximum(abs, reference.residual) <= 2.0e-12
            push!(times, next_time)
            states = hcat(states, reference.state)
        end
        push!(errors, maximum(abs, states[:, end] - exact))
    end
    @test errors[2] < errors[1]
    @test errors[3] < errors[2]
    @test errors[1] / errors[2] >= 2.5
    @test errors[2] / errors[3] >= 2.5

    @test_throws ArgumentError independent_bdf_derivative_weights([0.0, 0.0])
    @test_throws ArgumentError IndependentPassiveRLCDAEParameters(
        source_voltage_v=120.0,
        source_resistance_ohm=0.0,
        inductance_h=15.0e-3,
        capacitance_f=100.0e-6,
        load_resistance_ohm=24.0,
    )
end

@testset "independent manufactured and Robertson index-one DAEs" begin
    manufactured = IndependentManufacturedIndexOneDAEParameters(
        stiffness_per_s=1.0e4,
        nonlinear_rate_per_s=1.0,
    )
    for time_s in (0.0, 1.0e-4, 0.1, 1.0)
        state = independent_manufactured_index_one_state(manufactured, time_s)
        derivative = independent_manufactured_index_one_derivative(manufactured, time_s)
        @test maximum(abs, independent_manufactured_index_one_residual(
            manufactured,
            time_s,
            state,
            derivative,
        )) <= 2.0e-13
        state_jacobian, derivative_jacobian =
            independent_manufactured_index_one_jacobians(manufactured, state)
        @test size(state_jacobian) == (3, 3)
        @test derivative_jacobian == Diagonal([1.0, 1.0, 0.0])
    end

    robertson = IndependentRobertsonDAEParameters()
    @test independent_robertson_dae_residual(
        robertson,
        [1.0, 0.0, 0.0],
        [-0.04, 0.04, 0.0],
    ) == zeros(3)
    reference = independent_robertson_backward_euler(
        robertson,
        1.0e-4;
        step_s=1.0e-8,
    )
    @test reference.time_s ≈ 1.0e-4 atol=eps(1.0e-4)
    @test minimum(reference.state) >= 0.0
    @test sum(reference.state) ≈ 1.0 atol=2.0e-15
    @test maximum(abs, reference.residual) <= 2.0e-13
    @test reference.total_iterations > 0
    state_jacobian, derivative_jacobian = independent_robertson_dae_jacobians(
        robertson,
        reference.state,
    )
    @test size(state_jacobian) == (3, 3)
    @test derivative_jacobian == Diagonal([1.0, 1.0, 0.0])

    @test_throws ArgumentError IndependentManufacturedIndexOneDAEParameters(
        stiffness_per_s=0.0,
        nonlinear_rate_per_s=1.0,
    )
    @test_throws ArgumentError IndependentRobertsonDAEParameters(
        recombination_rate_per_s=0.0,
    )
end
