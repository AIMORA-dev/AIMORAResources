struct IndependentPassiveRLCDAEParameters
    source_voltage_v::Float64
    source_resistance_ohm::Float64
    inductance_h::Float64
    capacitance_f::Float64
    load_resistance_ohm::Float64

    function IndependentPassiveRLCDAEParameters(;
        source_voltage_v::Real,
        source_resistance_ohm::Real,
        inductance_h::Real,
        capacitance_f::Real,
        load_resistance_ohm::Real,
    )
        values = Float64.(Tuple((
            source_voltage_v,
            source_resistance_ohm,
            inductance_h,
            capacitance_f,
            load_resistance_ohm,
        )))
        all(isfinite, values) || throw(ArgumentError(
            "independent passive RLC parameters must be finite",
        ))
        source, source_resistance, inductance, capacitance,
            load_resistance = values
        source_resistance > 0.0 || throw(ArgumentError(
            "independent source resistance must be positive",
        ))
        inductance > 0.0 || throw(ArgumentError(
            "independent inductance must be positive",
        ))
        capacitance > 0.0 || throw(ArgumentError(
            "independent capacitance must be positive",
        ))
        load_resistance > 0.0 || throw(ArgumentError(
            "independent load resistance must be positive",
        ))
        return new(
            source,
            source_resistance,
            inductance,
            capacitance,
            load_resistance,
        )
    end
end

"""Independent variable-node derivative weights from polynomial moment equations."""
function independent_bdf_derivative_weights(nodes_s)
    nodes = Float64[Float64(node) for node in nodes_s]
    2 <= length(nodes) <= 6 || throw(ArgumentError(
        "independent BDF reference requires two through six nodes",
    ))
    all(isfinite, nodes) || throw(ArgumentError(
        "independent BDF nodes must be finite",
    ))
    length(nodes) == length(unique(nodes)) || throw(ArgumentError(
        "independent BDF nodes must be distinct",
    ))
    span = maximum(nodes) - minimum(nodes)
    span > 0.0 || throw(ArgumentError(
        "independent BDF nodes must have positive span",
    ))
    # This is an evidence formulation, so solve the small Vandermonde moment
    # system at higher precision and round only the final physical weights.
    # That avoids making the reference share the production weight algorithm
    # while keeping fifth-order coefficient identities near roundoff.
    return setprecision(BigFloat, 256) do
        big_nodes = BigFloat.(nodes)
        big_span = maximum(big_nodes) - minimum(big_nodes)
        offsets = (big_nodes .- big_nodes[1]) ./ big_span
        moment_matrix = Matrix{BigFloat}(undef, length(nodes), length(nodes))
        for degree in 0:(length(nodes) - 1)
            moment_matrix[degree + 1, :] .= offsets .^ degree
        end
        derivative_moments = zeros(BigFloat, length(nodes))
        derivative_moments[2] = one(BigFloat)
        return Float64.((moment_matrix \ derivative_moments) ./ big_span)
    end
end

function independent_passive_rlc_dae_residual(
    parameters::IndependentPassiveRLCDAEParameters,
    state,
    derivative,
)
    length(state) == 2 && length(derivative) == 2 || throw(DimensionMismatch(
        "independent passive RLC state and derivative must contain current and voltage",
    ))
    current_a, voltage_v = Float64.(state)
    current_rate_a_per_s, voltage_rate_v_per_s = Float64.(derivative)
    all(isfinite, (
        current_a,
        voltage_v,
        current_rate_a_per_s,
        voltage_rate_v_per_s,
    )) || throw(ArgumentError(
        "independent passive RLC state and derivative must be finite",
    ))
    return [
        parameters.inductance_h * current_rate_a_per_s - (
            parameters.source_voltage_v -
            parameters.source_resistance_ohm * current_a -
            voltage_v
        ),
        parameters.capacitance_f * voltage_rate_v_per_s - (
            current_a - voltage_v / parameters.load_resistance_ohm
        ),
    ]
end

function independent_passive_rlc_initial_derivative(
    parameters::IndependentPassiveRLCDAEParameters,
    state,
)
    length(state) == 2 || throw(DimensionMismatch(
        "independent passive RLC state must contain current and voltage",
    ))
    current_a, voltage_v = Float64.(state)
    return [
        (
            parameters.source_voltage_v -
            parameters.source_resistance_ohm * current_a -
            voltage_v
        ) / parameters.inductance_h,
        (current_a - voltage_v / parameters.load_resistance_ohm) /
            parameters.capacitance_f,
    ]
end

function independent_passive_rlc_exact_state(
    parameters::IndependentPassiveRLCDAEParameters,
    elapsed_time_s::Real,
    initial_state,
)
    elapsed = Float64(elapsed_time_s)
    isfinite(elapsed) && elapsed >= 0.0 || throw(ArgumentError(
        "independent passive RLC elapsed time must be finite and nonnegative",
    ))
    length(initial_state) == 2 || throw(DimensionMismatch(
        "independent passive RLC initial state must contain current and voltage",
    ))
    initial = Float64[Float64(value) for value in initial_state]
    all(isfinite, initial) || throw(ArgumentError(
        "independent passive RLC initial state must be finite",
    ))
    system_matrix = [
        -parameters.source_resistance_ohm / parameters.inductance_h -inv(parameters.inductance_h)
        inv(parameters.capacitance_f) -inv(parameters.load_resistance_ohm * parameters.capacitance_f)
    ]
    forcing = [
        parameters.source_voltage_v / parameters.inductance_h,
        0.0,
    ]
    equilibrium = -(system_matrix \ forcing)
    return equilibrium + exp(system_matrix * elapsed) * (initial - equilibrium)
end

function independent_passive_rlc_bdf_step(
    parameters::IndependentPassiveRLCDAEParameters,
    candidate_time_s::Real,
    accepted_times_s,
    accepted_states,
)
    accepted_times = Float64[Float64(time) for time in accepted_times_s]
    1 <= length(accepted_times) <= 5 || throw(ArgumentError(
        "independent passive RLC BDF step requires one through five accepted states",
    ))
    states = Matrix{Float64}(accepted_states)
    size(states) == (2, length(accepted_times)) || throw(DimensionMismatch(
        "independent passive RLC history shape must be two by accepted-state count",
    ))
    candidate_time = Float64(candidate_time_s)
    candidate_time > accepted_times[end] || throw(ArgumentError(
        "independent passive RLC candidate time must advance accepted time",
    ))
    nodes = vcat(candidate_time, reverse(accepted_times))
    weights = independent_bdf_derivative_weights(nodes)
    history = reverse(states; dims=2)
    current_history = dot(@view(weights[2:end]), @view(history[1, :]))
    voltage_history = dot(@view(weights[2:end]), @view(history[2, :]))
    coefficient_matrix = [
        parameters.inductance_h * weights[1] + parameters.source_resistance_ohm 1.0
        -1.0 parameters.capacitance_f * weights[1] + inv(parameters.load_resistance_ohm)
    ]
    right_hand_side = [
        parameters.source_voltage_v - parameters.inductance_h * current_history,
        -parameters.capacitance_f * voltage_history,
    ]
    state = coefficient_matrix \ right_hand_side
    derivative = [
        weights[1] * state[1] + current_history,
        weights[1] * state[2] + voltage_history,
    ]
    return (
        state=state,
        derivative=derivative,
        residual=independent_passive_rlc_dae_residual(parameters, state, derivative),
        derivative_weights=weights,
    )
end

function independent_passive_rlc_energy_balance(
    parameters::IndependentPassiveRLCDAEParameters,
    state,
    derivative,
)
    length(state) == 2 && length(derivative) == 2 || throw(DimensionMismatch(
        "independent passive RLC energy state must contain current and voltage",
    ))
    current_a, voltage_v = Float64.(state)
    current_rate_a_per_s, voltage_rate_v_per_s = Float64.(derivative)
    stored_energy_j = 0.5 * parameters.inductance_h * current_a^2 +
        0.5 * parameters.capacitance_f * voltage_v^2
    stored_power_w = parameters.inductance_h * current_a * current_rate_a_per_s +
        parameters.capacitance_f * voltage_v * voltage_rate_v_per_s
    source_power_w = parameters.source_voltage_v * current_a
    source_resistive_loss_w = parameters.source_resistance_ohm * current_a^2
    load_loss_w = voltage_v^2 / parameters.load_resistance_ohm
    return (
        stored_energy_j=stored_energy_j,
        stored_power_w=stored_power_w,
        source_power_w=source_power_w,
        source_resistive_loss_w=source_resistive_loss_w,
        load_loss_w=load_loss_w,
        balance_residual_w=stored_power_w - (
            source_power_w - source_resistive_loss_w - load_loss_w
        ),
    )
end

struct IndependentManufacturedIndexOneDAEParameters
    stiffness_per_s::Float64
    nonlinear_rate_per_s::Float64

    function IndependentManufacturedIndexOneDAEParameters(;
        stiffness_per_s::Real,
        nonlinear_rate_per_s::Real,
    )
        stiffness = Float64(stiffness_per_s)
        nonlinear_rate = Float64(nonlinear_rate_per_s)
        isfinite(stiffness) && stiffness > 0.0 || throw(ArgumentError(
            "independent manufactured DAE stiffness must be finite and positive",
        ))
        isfinite(nonlinear_rate) && nonlinear_rate > 0.0 || throw(ArgumentError(
            "independent manufactured DAE nonlinear rate must be finite and positive",
        ))
        return new(stiffness, nonlinear_rate)
    end
end

function independent_manufactured_index_one_state(
    parameters::IndependentManufacturedIndexOneDAEParameters,
    time_s::Real,
)
    time = Float64(time_s)
    isfinite(time) && time >= 0.0 || throw(ArgumentError(
        "independent manufactured DAE time must be finite and nonnegative",
    ))
    linear_state = cos(time)
    nonlinear_state = inv(1.0 + parameters.nonlinear_rate_per_s * time)
    algebraic_state = linear_state + nonlinear_state^2
    return [linear_state, nonlinear_state, algebraic_state]
end

function independent_manufactured_index_one_derivative(
    parameters::IndependentManufacturedIndexOneDAEParameters,
    time_s::Real,
)
    time = Float64(time_s)
    state = independent_manufactured_index_one_state(parameters, time)
    return [
        -sin(time),
        -parameters.nonlinear_rate_per_s * state[2]^2,
        0.0,
    ]
end

function independent_manufactured_index_one_residual(
    parameters::IndependentManufacturedIndexOneDAEParameters,
    time_s::Real,
    state,
    derivative,
)
    length(state) == 3 && length(derivative) == 3 || throw(DimensionMismatch(
        "independent manufactured DAE requires three state and derivative values",
    ))
    time = Float64(time_s)
    values = Float64.(state)
    rates = Float64.(derivative)
    all(isfinite, (time, values..., rates...)) || throw(ArgumentError(
        "independent manufactured DAE inputs must be finite",
    ))
    linear_state, nonlinear_state, algebraic_state = values
    return [
        rates[1] + sin(time) +
            parameters.stiffness_per_s * (linear_state - cos(time)),
        rates[2] + parameters.nonlinear_rate_per_s * nonlinear_state^2,
        algebraic_state - linear_state - nonlinear_state^2,
    ]
end

function independent_manufactured_index_one_jacobians(
    parameters::IndependentManufacturedIndexOneDAEParameters,
    state,
)
    length(state) == 3 || throw(DimensionMismatch(
        "independent manufactured DAE Jacobian requires three state values",
    ))
    values = Float64.(state)
    all(isfinite, values) || throw(ArgumentError(
        "independent manufactured DAE Jacobian state must be finite",
    ))
    state_jacobian = [
        parameters.stiffness_per_s 0.0 0.0
        0.0 2.0 * parameters.nonlinear_rate_per_s * values[2] 0.0
        -1.0 -2.0 * values[2] 1.0
    ]
    derivative_jacobian = [
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 0.0
    ]
    return state_jacobian, derivative_jacobian
end

struct IndependentRobertsonDAEParameters
    slow_rate_per_s::Float64
    coupling_rate_per_s::Float64
    recombination_rate_per_s::Float64

    function IndependentRobertsonDAEParameters(;
        slow_rate_per_s::Real=0.04,
        coupling_rate_per_s::Real=1.0e4,
        recombination_rate_per_s::Real=3.0e7,
    )
        values = Float64.((
            slow_rate_per_s,
            coupling_rate_per_s,
            recombination_rate_per_s,
        ))
        all(value -> isfinite(value) && value > 0.0, values) || throw(ArgumentError(
            "independent Robertson rates must be finite and positive",
        ))
        return new(values...)
    end
end

function independent_robertson_dae_residual(
    parameters::IndependentRobertsonDAEParameters,
    state,
    derivative,
)
    length(state) == 3 && length(derivative) == 3 || throw(DimensionMismatch(
        "independent Robertson DAE requires three state and derivative values",
    ))
    y1, y2, y3 = Float64.(state)
    dy1, dy2, _ = Float64.(derivative)
    all(isfinite, (y1, y2, y3, dy1, dy2)) || throw(ArgumentError(
        "independent Robertson DAE inputs must be finite",
    ))
    return [
        dy1 + parameters.slow_rate_per_s * y1 -
            parameters.coupling_rate_per_s * y2 * y3,
        dy2 - parameters.slow_rate_per_s * y1 +
            parameters.coupling_rate_per_s * y2 * y3 +
            parameters.recombination_rate_per_s * y2^2,
        y1 + y2 + y3 - 1.0,
    ]
end

function independent_robertson_dae_jacobians(
    parameters::IndependentRobertsonDAEParameters,
    state,
)
    length(state) == 3 || throw(DimensionMismatch(
        "independent Robertson DAE Jacobian requires three state values",
    ))
    y1, y2, y3 = Float64.(state)
    all(isfinite, (y1, y2, y3)) || throw(ArgumentError(
        "independent Robertson DAE Jacobian state must be finite",
    ))
    state_jacobian = [
        parameters.slow_rate_per_s -parameters.coupling_rate_per_s * y3 -parameters.coupling_rate_per_s * y2
        -parameters.slow_rate_per_s parameters.coupling_rate_per_s * y3 + 2.0 * parameters.recombination_rate_per_s * y2 parameters.coupling_rate_per_s * y2
        1.0 1.0 1.0
    ]
    derivative_jacobian = [
        1.0 0.0 0.0
        0.0 1.0 0.0
        0.0 0.0 0.0
    ]
    return state_jacobian, derivative_jacobian
end

"""Independent fixed-step backward-Euler Robertson reference on the reduced conservation manifold."""
function independent_robertson_backward_euler(
    parameters::IndependentRobertsonDAEParameters,
    stop_time_s::Real;
    step_s::Real=1.0e-8,
    tolerance::Real=1.0e-8,
    maximum_iterations::Integer=20,
)
    stop_time = Float64(stop_time_s)
    nominal_step = Float64(step_s)
    tolerance_value = Float64(tolerance)
    iteration_limit = Int(maximum_iterations)
    isfinite(stop_time) && stop_time > 0.0 || throw(ArgumentError(
        "independent Robertson stop time must be finite and positive",
    ))
    isfinite(nominal_step) && nominal_step > 0.0 || throw(ArgumentError(
        "independent Robertson step must be finite and positive",
    ))
    isfinite(tolerance_value) && tolerance_value > 0.0 && iteration_limit >= 2 ||
        throw(ArgumentError("independent Robertson Newton settings are invalid"))
    state = [1.0, 0.0, 0.0]
    time_s = 0.0
    total_iterations = 0
    maximum_residual = 0.0
    while time_s < stop_time
        remaining_time_s = stop_time - time_s
        if remaining_time_s <= 64.0 * eps(Float64) * max(stop_time, 1.0)
            time_s = stop_time
            break
        end
        step = min(nominal_step, remaining_time_s)
        previous_y1 = state[1]
        previous_y2 = state[2]
        y1 = previous_y1
        y2 = max(previous_y2, 0.0)
        converged = false
        for _ in 1:iteration_limit
            total_iterations += 1
            y3 = 1.0 - y1 - y2
            residual = [
                (y1 - previous_y1) / step + parameters.slow_rate_per_s * y1 -
                    parameters.coupling_rate_per_s * y2 * y3,
                (y2 - previous_y2) / step - parameters.slow_rate_per_s * y1 +
                    parameters.coupling_rate_per_s * y2 * y3 +
                    parameters.recombination_rate_per_s * y2^2,
            ]
            maximum_residual = max(maximum_residual, maximum(abs, residual))
            if maximum(abs, residual) <= tolerance_value
                converged = true
                break
            end
            jacobian = [
                inv(step) + parameters.slow_rate_per_s + parameters.coupling_rate_per_s * y2 -parameters.coupling_rate_per_s * (y3 - y2)
                -parameters.slow_rate_per_s - parameters.coupling_rate_per_s * y2 inv(step) + parameters.coupling_rate_per_s * (y3 - y2) + 2.0 * parameters.recombination_rate_per_s * y2
            ]
            correction = jacobian \ residual
            y1 -= correction[1]
            y2 -= correction[2]
        end
        converged || throw(ArgumentError(
            "independent Robertson backward-Euler Newton solve did not converge",
        ))
        state .= (y1, y2, 1.0 - y1 - y2)
        minimum(state) >= -1.0e-14 || throw(ArgumentError(
            "independent Robertson reference left the nonnegative concentration domain",
        ))
        time_s = min(stop_time, time_s + step)
    end
    derivative = [
        -parameters.slow_rate_per_s * state[1] +
            parameters.coupling_rate_per_s * state[2] * state[3],
        parameters.slow_rate_per_s * state[1] -
            parameters.coupling_rate_per_s * state[2] * state[3] -
            parameters.recombination_rate_per_s * state[2]^2,
        0.0,
    ]
    return (
        time_s,
        state,
        derivative,
        residual=independent_robertson_dae_residual(parameters, state, derivative),
        total_iterations,
        maximum_residual,
    )
end
