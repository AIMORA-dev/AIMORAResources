using Test
using LinearAlgebra
using AIMORAReferenceModels

@testset "Independent complete coupled line recurrence Norton and convolution" begin
    rate_per_s = 2.0 * pi * 400.0
    direct = [0.05 0.01; 0.01 0.04]
    normalized_residue = [0.20 0.03; 0.03 0.15]
    state_matrix = -rate_per_s .* Matrix{Float64}(I, 2, 2)
    input_matrix = Matrix{Float64}(I, 2, 2)
    output_matrix = rate_per_s .* normalized_residue
    reference = [40.0, 60.0]
    timestep_s = 10.0e-6
    model = independent_coupled_line_discretization(
        state_matrix,
        input_matrix,
        output_matrix,
        direct,
        reference,
        timestep_s,
    )
    expected_pole = (model.bilinear_alpha_per_s - rate_per_s) /
        (model.bilinear_alpha_per_s + rate_per_s)
    @test eigvals(model.state_transition) ≈ fill(expected_pole, 2) atol=1.0e-14
    frequency_hz = 600.0
    mapped_s = 1.0im * model.bilinear_alpha_per_s *
        tan(pi * frequency_hz * timestep_s)
    continuous_response = direct + output_matrix *
        ((mapped_s .* Matrix{ComplexF64}(I, 2, 2) .- state_matrix) \ input_matrix)
    @test independent_coupled_discrete_response(model, frequency_hz) ≈
        continuous_response atol=1.0e-14

    incident_waves = [
        ComplexF64[
            sin(0.17 * sample) + 0.1im * cos(0.11 * sample),
            0.4cos(0.09 * sample) - 0.2im * sin(0.13 * sample),
        ] for sample in 0:40
    ]
    dense = independent_coupled_dense_convolution(model, incident_waves)
    rational_state = zeros(ComplexF64, 2)
    previous_incident = zeros(ComplexF64, 2)
    recurrence = Vector{Vector{ComplexF64}}()
    for incident in incident_waves
        step = independent_coupled_incident_step(
            model,
            rational_state,
            previous_incident,
            incident,
        )
        rational_state = step.rational_state
        previous_incident = incident
        push!(recurrence, step.outgoing_wave)
    end
    @test maximum(
        maximum(abs, dense[index] - recurrence[index]; init=0.0)
        for index in eachindex(dense)
    ) <= 2.0e-15

    state = independent_coupled_deenergized_state(model)
    voltage_v = [100.0, -25.0]
    step = independent_coupled_terminal_step(model, state, voltage_v)
    @test step.kcl_residual_a <= 2.0e-15
    @test step.state.accepted_step_count == 1
    @test step.state.terminal_current_a ≈
        step.companion_admittance_s * voltage_v + step.history_current_a atol=2.0e-15
    @test step.state.cumulative_supplied_energy_j >= -eps(Float64)
end

@testset "Independent coupled line sinusoidal state energy and continuation" begin
    rate_per_s = 2.0 * pi * 300.0
    direct = [0.04 0.01; 0.01 0.05]
    output_matrix = rate_per_s .* [0.18 0.02; 0.02 0.14]
    model = independent_coupled_line_discretization(
        -rate_per_s .* Matrix{Float64}(I, 2, 2),
        Matrix{Float64}(I, 2, 2),
        output_matrix,
        direct,
        [50.0, 50.0],
        20.0e-6,
    )
    frequency_hz = 60.0
    voltage_phasor_v = ComplexF64[120.0 + 10.0im, -40.0 + 15.0im]
    scattering = independent_coupled_discrete_response(model, frequency_hz)
    current_phasor_a = independent_coupled_scattering_to_admittance(
        scattering,
        model.reference_impedance_ohm,
    ) * voltage_phasor_v
    state = independent_coupled_sinusoidal_state(
        model,
        voltage_phasor_v,
        frequency_hz,
    )
    @test state.terminal_current_a ≈ real.(current_phasor_a) atol=2.0e-14
    snapshot = state
    angle = 2.0 * pi * frequency_hz * model.timestep_s
    times_s = [0.0]
    voltages_v = [copy(state.terminal_voltage_v)]
    currents_a = [copy(state.terminal_current_a)]
    for step_index in 1:20
        voltage_v = real.(voltage_phasor_v .* cis(step_index * angle))
        result = independent_coupled_terminal_step(model, state, voltage_v)
        state = result.state
        @test state.terminal_current_a ≈
            real.(current_phasor_a .* cis(step_index * angle)) atol=2.0e-11
        push!(times_s, step_index * model.timestep_s)
        push!(voltages_v, copy(state.terminal_voltage_v))
        push!(currents_a, copy(state.terminal_current_a))
    end
    energy = independent_coupled_terminal_energy(times_s, voltages_v, currents_a)
    @test last(energy.cumulative_energy_j) ≈ state.cumulative_supplied_energy_j atol=1.0e-15

    replay = snapshot
    for step_index in 1:20
        voltage_v = real.(voltage_phasor_v .* cis(step_index * angle))
        replay = independent_coupled_terminal_step(model, replay, voltage_v).state
    end
    @test all(
        name -> getfield(replay, name) == getfield(state, name),
        fieldnames(typeof(state)),
    )
    @test_throws ArgumentError independent_coupled_line_discretization(
        [1.0;;],
        [1.0;;],
        [1.0;;],
        [0.0;;],
        [50.0],
        model.timestep_s,
    )
end
