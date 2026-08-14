export IndependentCoupledLineDiscreteModel,
       IndependentCoupledLineRuntimeState,
       independent_coupled_line_discretization,
       independent_coupled_discrete_response,
       independent_coupled_norton_terms,
       independent_coupled_incident_step,
       independent_coupled_dense_convolution,
       independent_coupled_deenergized_state,
       independent_coupled_sinusoidal_state,
       independent_coupled_terminal_step,
       independent_coupled_terminal_energy

"""Independent bilinear discrete realization of one complete coupled scattering model."""
struct IndependentCoupledLineDiscreteModel
    timestep_s::Float64
    bilinear_alpha_per_s::Float64
    state_transition::Matrix{Float64}
    endpoint_input::Matrix{Float64}
    output_matrix::Matrix{Float64}
    continuous_direct_term::Matrix{Float64}
    discrete_direct_term::Matrix{Float64}
    reference_impedance_ohm::Vector{Float64}
    reference_sqrt_ohm_sqrt::Vector{Float64}
    reference_inverse_sqrt_per_ohm_sqrt::Vector{Float64}
end

"""Immutable accepted-boundary state used by the independent coupled-line recurrence."""
struct IndependentCoupledLineRuntimeState
    rational_state::Vector{Float64}
    previous_incident_wave::Vector{Float64}
    incident_wave::Vector{Float64}
    outgoing_wave::Vector{Float64}
    terminal_voltage_v::Vector{Float64}
    terminal_current_a::Vector{Float64}
    terminal_power_w::Float64
    cumulative_supplied_energy_j::Float64
    accepted_step_count::Int
end

function _independent_finite_real_matrix(values, label::AbstractString)
    matrix = Matrix{Float64}(values)
    all(isfinite, matrix) || throw(ArgumentError("$label must be finite"))
    return matrix
end

"""
Discretize `xdot=A*x+B*a, b=C*x+D*a` by the endpoint trapezoidal rule.

This implementation consumes plain matrices and derives every discrete matrix
directly; it does not consume an AIMORA production fit, runtime preparation, or
history owner.
"""
function independent_coupled_line_discretization(
    state_matrix_per_s,
    input_matrix,
    output_matrix_per_s,
    direct_term,
    reference_impedance_ohm,
    timestep_s::Real;
    prewarp_frequency_hz::Union{Nothing,Real}=nothing,
)
    state = _independent_finite_real_matrix(
        state_matrix_per_s,
        "independent coupled-line state matrix",
    )
    input = _independent_finite_real_matrix(
        input_matrix,
        "independent coupled-line input matrix",
    )
    output = _independent_finite_real_matrix(
        output_matrix_per_s,
        "independent coupled-line output matrix",
    )
    direct = _independent_finite_real_matrix(
        direct_term,
        "independent coupled-line direct term",
    )
    state_count = size(state, 1)
    port_count = size(direct, 1)
    state_count > 0 && size(state) == (state_count, state_count) ||
        throw(DimensionMismatch("independent coupled-line state matrix must be square"))
    port_count > 0 && size(direct) == (port_count, port_count) ||
        throw(DimensionMismatch("independent coupled-line direct term must be square"))
    size(input) == (state_count, port_count) &&
        size(output) == (port_count, state_count) ||
        throw(DimensionMismatch(
            "independent coupled-line state input and output dimensions disagree",
        ))
    maximum(real, eigvals(state); init=-Inf) < 0.0 ||
        throw(ArgumentError("independent coupled-line state matrix must be stable"))
    reference = _independent_reference_diagonal(
        reference_impedance_ohm,
        port_count,
    )
    timestep = Float64(timestep_s)
    isfinite(timestep) && timestep > 0.0 ||
        throw(ArgumentError("independent coupled-line timestep must be positive"))
    alpha = if prewarp_frequency_hz === nothing
        2.0 / timestep
    else
        prewarp = Float64(prewarp_frequency_hz)
        isfinite(prewarp) && prewarp > 0.0 &&
            prewarp * timestep < 0.5 - 64.0 * eps(Float64) ||
            throw(ArgumentError(
                "independent coupled-line prewarp must be positive and below Nyquist",
            ))
        angular_frequency = 2.0 * pi * prewarp
        angular_frequency / tan(0.5 * angular_frequency * timestep)
    end
    identity_state = Matrix{Float64}(I, state_count, state_count)
    endpoint_solve = alpha .* identity_state .- state
    isfinite(cond(endpoint_solve)) || throw(ArgumentError(
        "independent coupled-line endpoint solve is singular",
    ))
    state_transition = endpoint_solve \ (alpha .* identity_state .+ state)
    endpoint_input = endpoint_solve \ input
    discrete_direct = direct + output * endpoint_input
    return IndependentCoupledLineDiscreteModel(
        timestep,
        alpha,
        state_transition,
        endpoint_input,
        output,
        direct,
        discrete_direct,
        reference,
        sqrt.(reference),
        inv.(sqrt.(reference)),
    )
end

"""Evaluate the independent discrete scattering response at one physical frequency."""
function independent_coupled_discrete_response(
    model::IndependentCoupledLineDiscreteModel,
    frequency_hz::Real,
)
    frequency = Float64(frequency_hz)
    isfinite(frequency) && frequency >= 0.0 &&
        frequency * model.timestep_s < 0.5 ||
        throw(ArgumentError(
            "independent coupled-line frequency must be finite, nonnegative, and below Nyquist",
        ))
    z = cis(2.0 * pi * frequency * model.timestep_s)
    state_count = size(model.state_transition, 1)
    state_response = (z .* Matrix{ComplexF64}(I, state_count, state_count) .-
        model.state_transition) \ (model.endpoint_input .* (z + 1.0))
    return ComplexF64.(model.continuous_direct_term) .+
        model.output_matrix * state_response
end

"""Form the complete independent Norton matrix and history source for one accepted boundary."""
function independent_coupled_norton_terms(
    model::IndependentCoupledLineDiscreteModel,
    rational_state,
    previous_incident_wave,
)
    state = Float64.(rational_state)
    previous_incident = Float64.(previous_incident_wave)
    state_count = size(model.state_transition, 1)
    port_count = size(model.discrete_direct_term, 1)
    length(state) == state_count && length(previous_incident) == port_count ||
        throw(DimensionMismatch("independent coupled-line Norton state dimensions disagree"))
    history_wave = model.output_matrix * model.state_transition * state +
        model.output_matrix * model.endpoint_input * previous_incident
    identity_ports = Matrix{Float64}(I, port_count, port_count)
    wave_solve = (identity_ports + model.discrete_direct_term) \ identity_ports
    inverse_root = Diagonal(model.reference_inverse_sqrt_per_ohm_sqrt)
    companion = inverse_root * (identity_ports - model.discrete_direct_term) *
        wave_solve * inverse_root
    history_current = -inverse_root * (
        (identity_ports - model.discrete_direct_term) * wave_solve * history_wave +
        history_wave
    )
    return (; companion_admittance_s=companion, history_current_a=history_current,
        history_wave)
end

"""Advance the independent scattering recurrence for a prescribed incident wave."""
function independent_coupled_incident_step(
    model::IndependentCoupledLineDiscreteModel,
    rational_state,
    previous_incident_wave,
    incident_wave,
)
    scalar_type = promote_type(
        eltype(rational_state),
        eltype(previous_incident_wave),
        eltype(incident_wave),
        Float64,
    )
    state = scalar_type.(rational_state)
    previous_incident = scalar_type.(previous_incident_wave)
    incident = scalar_type.(incident_wave)
    state_count = size(model.state_transition, 1)
    port_count = size(model.discrete_direct_term, 1)
    length(state) == state_count && length(previous_incident) == port_count &&
        length(incident) == port_count ||
        throw(DimensionMismatch("independent coupled-line incident recurrence dimensions disagree"))
    next_state = model.state_transition * state +
        model.endpoint_input * (incident + previous_incident)
    outgoing = model.output_matrix * next_state +
        model.continuous_direct_term * incident
    return (; rational_state=next_state, outgoing_wave=outgoing)
end

"""Evaluate the same discrete response as an explicit dense causal convolution."""
function independent_coupled_dense_convolution(
    model::IndependentCoupledLineDiscreteModel,
    incident_waves,
)
    isempty(incident_waves) && return Vector{Vector{ComplexF64}}()
    port_count = size(model.discrete_direct_term, 1)
    incident = [ComplexF64.(wave) for wave in incident_waves]
    all(wave -> length(wave) == port_count, incident) ||
        throw(DimensionMismatch("independent dense-convolution incident dimensions disagree"))
    impulse = Matrix{Float64}[model.discrete_direct_term]
    state_power = Matrix{Float64}(I, size(model.state_transition, 1),
        size(model.state_transition, 1))
    endpoint_sum = (model.state_transition +
        Matrix{Float64}(I, size(model.state_transition)...)) * model.endpoint_input
    for _lag in 1:(length(incident) - 1)
        push!(impulse, model.output_matrix * state_power * endpoint_sum)
        state_power = state_power * model.state_transition
    end
    outgoing = Vector{Vector{ComplexF64}}(undef, length(incident))
    for sample in eachindex(incident)
        value = zeros(ComplexF64, port_count)
        for lag in 0:(sample - 1)
            value .+= impulse[lag + 1] * incident[sample - lag]
        end
        outgoing[sample] = value
    end
    return outgoing
end

function independent_coupled_deenergized_state(
    model::IndependentCoupledLineDiscreteModel,
)
    state_count = size(model.state_transition, 1)
    port_count = size(model.discrete_direct_term, 1)
    return IndependentCoupledLineRuntimeState(
        zeros(state_count),
        zeros(port_count),
        zeros(port_count),
        zeros(port_count),
        zeros(port_count),
        zeros(port_count),
        0.0,
        0.0,
        0,
    )
end

"""Construct an independent exact discrete sinusoidal accepted-boundary state."""
function independent_coupled_sinusoidal_state(
    model::IndependentCoupledLineDiscreteModel,
    terminal_voltage_phasor_v,
    frequency_hz::Real,
)
    voltage_phasor = ComplexF64.(terminal_voltage_phasor_v)
    port_count = size(model.discrete_direct_term, 1)
    length(voltage_phasor) == port_count || throw(DimensionMismatch(
        "independent sinusoidal initialization voltage count must match ports",
    ))
    scattering = independent_coupled_discrete_response(model, frequency_hz)
    admittance = independent_coupled_scattering_to_admittance(
        scattering,
        model.reference_impedance_ohm,
    )
    current_phasor = admittance * voltage_phasor
    incident_phasor = 0.5 .* (
        model.reference_inverse_sqrt_per_ohm_sqrt .* voltage_phasor .+
        model.reference_sqrt_ohm_sqrt .* current_phasor
    )
    z = cis(2.0 * pi * Float64(frequency_hz) * model.timestep_s)
    state_count = size(model.state_transition, 1)
    state_phasor = (z .* Matrix{ComplexF64}(I, state_count, state_count) .-
        model.state_transition) \ (model.endpoint_input * ((z + 1.0) .* incident_phasor))
    outgoing_phasor = model.output_matrix * state_phasor +
        model.continuous_direct_term * incident_phasor
    terminal_voltage = real.(voltage_phasor)
    terminal_current = real.(current_phasor)
    return IndependentCoupledLineRuntimeState(
        real.(state_phasor),
        real.(incident_phasor),
        real.(incident_phasor),
        real.(outgoing_phasor),
        terminal_voltage,
        terminal_current,
        dot(terminal_voltage, terminal_current),
        0.0,
        0,
    )
end

"""Advance one independent terminal-voltage-driven Norton/recurrence step."""
function independent_coupled_terminal_step(
    model::IndependentCoupledLineDiscreteModel,
    state::IndependentCoupledLineRuntimeState,
    terminal_voltage_v,
)
    voltage = Float64.(terminal_voltage_v)
    port_count = size(model.discrete_direct_term, 1)
    length(voltage) == port_count && all(isfinite, voltage) ||
        throw(ArgumentError("independent coupled-line terminal voltage is invalid"))
    norton = independent_coupled_norton_terms(
        model,
        state.rational_state,
        state.previous_incident_wave,
    )
    identity_ports = Matrix{Float64}(I, port_count, port_count)
    incident = (identity_ports + model.discrete_direct_term) \ (
        model.reference_inverse_sqrt_per_ohm_sqrt .* voltage .-
        norton.history_wave
    )
    recurrence = independent_coupled_incident_step(
        model,
        state.rational_state,
        state.previous_incident_wave,
        incident,
    )
    current = model.reference_inverse_sqrt_per_ohm_sqrt .* (
        incident - recurrence.outgoing_wave
    )
    companion_current = norton.companion_admittance_s * voltage +
        norton.history_current_a
    kcl_residual = maximum(abs, current - companion_current; init=0.0)
    power = dot(voltage, current)
    energy = state.cumulative_supplied_energy_j + 0.5 * model.timestep_s *
        (state.terminal_power_w + power)
    next_state = IndependentCoupledLineRuntimeState(
        real.(recurrence.rational_state),
        real.(incident),
        real.(incident),
        real.(recurrence.outgoing_wave),
        voltage,
        real.(current),
        power,
        energy,
        state.accepted_step_count + 1,
    )
    return (; state=next_state, kcl_residual_a=kcl_residual,
        companion_admittance_s=norton.companion_admittance_s,
        history_current_a=norton.history_current_a)
end

"""Independently integrate terminal power for aligned real voltage/current rows."""
function independent_coupled_terminal_energy(times_s, terminal_voltages_v, terminal_currents_a)
    times = Float64.(times_s)
    length(times) == length(terminal_voltages_v) == length(terminal_currents_a) &&
        length(times) >= 2 || throw(DimensionMismatch(
            "independent terminal energy rows must align",
        ))
    all(diff(times) .> 0.0) || throw(ArgumentError(
        "independent terminal energy times must be strictly increasing",
    ))
    power = [dot(Float64.(terminal_voltages_v[index]),
        Float64.(terminal_currents_a[index])) for index in eachindex(times)]
    energy = zeros(length(times))
    for index in 2:length(times)
        energy[index] = energy[index - 1] + 0.5 * (power[index - 1] + power[index]) *
            (times[index] - times[index - 1])
    end
    return (; instantaneous_power_w=power, cumulative_energy_j=energy)
end
