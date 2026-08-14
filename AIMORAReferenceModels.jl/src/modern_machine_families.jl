export IndependentMachineElectricalState,
       IndependentMachineShaftState,
       IndependentMachineControlState,
       independent_machine_phase_transform,
       independent_machine_family_matrices,
       independent_machine_coenergy,
       independent_machine_trapezoidal_step,
       independent_machine_shaft_step,
       independent_machine_control_step,
       independent_machine_consistent_flux,
       independent_machine_power_balance

struct IndependentMachineElectricalState
    flux_wb::Vector{Float64}
    current_a::Vector{Float64}
    terminal_current_a::Vector{Float64}
    terminal_jacobian_s::Matrix{Float64}
    electromagnetic_torque_nm::Float64
    magnetic_coenergy_j::Float64
    copper_loss_w::Float64
    residual_wb::Float64
    iterations::Int
end

struct IndependentMachineShaftState
    angle_rad::Vector{Float64}
    speed_rad_s::Vector{Float64}
    coupling_torque_nm::Vector{Float64}
    kinetic_energy_j::Float64
    elastic_energy_j::Float64
    damping_loss_w::Float64
    angular_momentum_residual_nms::Float64
end

struct IndependentMachineControlState
    sensed_voltage_v::Float64
    sampled_speed_rad_s::Float64
    excitation_state_v::Float64
    governor_state_nm::Float64
    stabilizer_washout_state::Float64
    stabilizer_lead_lag_state::Float64
    field_voltage_v::Float64
    mechanical_torque_nm::Float64
    field_limited::Bool
    torque_limited::Bool
end

"""Independently construct the orthonormal zero/d/q transform from scalar rows."""
function independent_machine_phase_transform(electrical_angle_rad::Real)
    angle = Float64(electrical_angle_rad)
    isfinite(angle) || throw(ArgumentError("independent machine angle must be finite"))
    transform = zeros(3, 3)
    for phase_index in 1:3
        phase_angle = angle - 2.0 * pi * (phase_index - 1) / 3.0
        transform[1, phase_index] = inv(sqrt(3.0))
        transform[2, phase_index] = sqrt(2.0 / 3.0) * cos(phase_angle)
        transform[3, phase_index] = -sqrt(2.0 / 3.0) * sin(phase_angle)
    end
    return transform
end

"""Construct a family winding matrix independently from scalar circuit data.

`family` is one of `:wound_field_synchronous`, `:cage_induction`,
`:wound_rotor_induction`, `:permanent_magnet_synchronous`,
`:doubly_fed_induction`, or `:synchronous_condenser`. `electrical` is a
plain named tuple and `rotor_branches` is a vector of plain named tuples, so
this formulation does not consume production family, layout, or matrix types.
"""
function independent_machine_family_matrices(family::Symbol, electrical, rotor_branches=NamedTuple[])
    synchronous = family in (:wound_field_synchronous, :synchronous_condenser)
    induction = family in (:cage_induction, :wound_rotor_induction, :doubly_fed_induction)
    permanent = family === :permanent_magnet_synchronous
    synchronous || induction || permanent || throw(ArgumentError(
        "independent machine family is unsupported",
    ))
    branch_count = length(rotor_branches)
    synchronous && branch_count != 0 && throw(ArgumentError(
        "independent synchronous family does not admit rotor branches",
    ))
    permanent && branch_count != 0 && throw(ArgumentError(
        "independent permanent-magnet family does not admit rotor branches",
    ))
    induction && !(1 <= branch_count <= 8) && throw(ArgumentError(
        "independent induction family requires one through eight rotor branches",
    ))
    d_leakage = Float64[electrical.stator_d_leakage_inductance_h]
    q_leakage = Float64[electrical.stator_q_leakage_inductance_h]
    d_resistance = Float64[electrical.stator_resistance_ohm]
    q_resistance = Float64[electrical.stator_resistance_ohm]
    if synchronous
        append!(d_leakage, (
            electrical.field_leakage_inductance_h,
            electrical.d_damper_leakage_inductance_h,
        ))
        push!(q_leakage, electrical.q_damper_leakage_inductance_h)
        append!(d_resistance, (
            electrical.field_resistance_ohm,
            electrical.d_damper_resistance_ohm,
        ))
        push!(q_resistance, electrical.q_damper_resistance_ohm)
    elseif induction
        append!(d_leakage, Float64.(getfield.(rotor_branches, :leakage_inductance_h)))
        append!(q_leakage, Float64.(getfield.(rotor_branches, :leakage_inductance_h)))
        append!(d_resistance, Float64.(getfield.(rotor_branches, :resistance_ohm)))
        append!(q_resistance, Float64.(getfield.(rotor_branches, :resistance_ohm)))
    end
    axis_matrix(leakage, magnetizing) =
        Matrix(Diagonal(leakage) + Float64(magnetizing) .* ones(length(leakage), length(leakage)))
    d_matrix = axis_matrix(d_leakage, electrical.d_axis_magnetizing_inductance_h)
    q_matrix = axis_matrix(q_leakage, electrical.q_axis_magnetizing_inductance_h)
    state_count = 1 + size(d_matrix, 1) + size(q_matrix, 1)
    zero_index = 1
    d_indices = 2:(1 + size(d_matrix, 1))
    q_indices = (last(d_indices) + 1):state_count
    inductance = zeros(state_count, state_count)
    resistance = zeros(state_count)
    offset = zeros(state_count)
    inductance[zero_index, zero_index] = electrical.zero_sequence_inductance_h
    inductance[d_indices, d_indices] .= d_matrix
    inductance[q_indices, q_indices] .= q_matrix
    resistance[zero_index] = electrical.stator_resistance_ohm
    resistance[d_indices] .= d_resistance
    resistance[q_indices] .= q_resistance
    permanent && (offset[first(d_indices)] = electrical.permanent_magnet_flux_wb)
    minimum(eigvals(Symmetric(inductance))) > 0.0 || throw(ArgumentError(
        "independent family inductance must be positive definite",
    ))
    return (
        inductance_h=inductance,
        inverse_inductance_per_h=inv(Symmetric(inductance)),
        resistance_ohm=resistance,
        permanent_flux_offset_wb=offset,
        zero_index,
        d_axis_index=first(d_indices),
        q_axis_index=first(q_indices),
        d_indices,
        q_indices,
    )
end

"""Independent convex coenergy gradient and Hessian with no production model types."""
function independent_machine_coenergy(
    flux_wb,
    inverse_inductance_per_h,
    permanent_flux_offset_wb;
    d_axis_index::Integer,
    q_axis_index::Integer,
    radial_coefficient_per_wb2_h::Real=0.0,
    cross_coefficient_per_wb2_h::Real=0.0,
)
    flux = Float64.(flux_wb)
    inverse_inductance = Matrix{Float64}(inverse_inductance_per_h)
    offset = Float64.(permanent_flux_offset_wb)
    count = length(flux)
    size(inverse_inductance) == (count, count) && length(offset) == count ||
        throw(DimensionMismatch("independent machine coenergy dimensions disagree"))
    all(isfinite, flux) && all(isfinite, inverse_inductance) && all(isfinite, offset) ||
        throw(ArgumentError("independent machine coenergy inputs must be finite"))
    d_index = Int(d_axis_index)
    q_index = Int(q_axis_index)
    1 <= d_index <= count && 1 <= q_index <= count && d_index != q_index ||
        throw(ArgumentError("independent machine d/q indices are invalid"))
    radial = Float64(radial_coefficient_per_wb2_h)
    cross = Float64(cross_coefficient_per_wb2_h)
    isfinite(radial) && radial >= 0.0 && isfinite(cross) && cross >= 0.0 ||
        throw(ArgumentError("independent machine saturation coefficients must be nonnegative"))
    displaced = flux - offset
    current = inverse_inductance * displaced
    hessian = copy(inverse_inductance)
    d_flux = displaced[d_index]
    q_flux = displaced[q_index]
    d2 = d_flux^2
    q2 = q_flux^2
    radius2 = d2 + q2
    current[d_index] += radial * radius2 * d_flux + cross * d_flux * q2
    current[q_index] += radial * radius2 * q_flux + cross * q_flux * d2
    hessian[d_index, d_index] += radial * (3.0 * d2 + q2) + cross * q2
    hessian[q_index, q_index] += radial * (d2 + 3.0 * q2) + cross * d2
    cross_derivative = 2.0 * (radial + cross) * d_flux * q_flux
    hessian[d_index, q_index] += cross_derivative
    hessian[q_index, d_index] += cross_derivative
    coenergy = 0.5 * dot(displaced, inverse_inductance * displaced) +
        0.25 * radial * radius2^2 + 0.5 * cross * d2 * q2
    return (
        current_a=current,
        current_flux_jacobian_per_h=hessian,
        magnetic_coenergy_j=coenergy,
        cross_derivative_per_h=hessian[d_index, q_index],
        reciprocal_cross_derivative_per_h=hessian[q_index, d_index],
    )
end

function _independent_machine_voltage_map(
    state_count::Int,
    zero_index::Int,
    d_index::Int,
    q_index::Int,
    electrical_angle_rad::Float64,
)
    phase_terminal = [
        1.0 0.0 0.0 -1.0
        0.0 1.0 0.0 -1.0
        0.0 0.0 1.0 -1.0
    ]
    transform = independent_machine_phase_transform(electrical_angle_rad)
    input = zeros(state_count, 4)
    transformed_terminal = transform * phase_terminal
    input[zero_index, :] .= transformed_terminal[1, :]
    input[d_index, :] .= transformed_terminal[2, :]
    input[q_index, :] .= transformed_terminal[3, :]
    selector = zeros(3, state_count)
    selector[1, zero_index] = 1.0
    selector[2, d_index] = 1.0
    selector[3, q_index] = 1.0
    output = transpose(phase_terminal) * transpose(transform) * selector
    return input, output
end

"""Independent implicit trapezoidal flux step and analytic terminal tangent.

All matrices and port voltages are supplied explicitly. This implementation owns
no production family layout, event, history, residual, stamp, or solver code.
"""
function independent_machine_trapezoidal_step(
    previous_flux_wb,
    previous_terminal_voltage_v,
    terminal_voltage_v,
    inverse_inductance_per_h,
    permanent_flux_offset_wb,
    resistance_ohm,
    auxiliary_voltage_v;
    zero_index::Integer,
    d_axis_index::Integer,
    q_axis_index::Integer,
    electrical_angle_rad::Real,
    mechanical_speed_rad_s::Real,
    pole_pairs::Integer,
    timestep_s::Real,
    radial_coefficient_per_wb2_h::Real=0.0,
    cross_coefficient_per_wb2_h::Real=0.0,
    tolerance::Real=1.0e-12,
    maximum_iterations::Integer=20,
)
    previous_flux = Float64.(previous_flux_wb)
    state_count = length(previous_flux)
    inverse_inductance = Matrix{Float64}(inverse_inductance_per_h)
    offset = Float64.(permanent_flux_offset_wb)
    resistance = Float64.(resistance_ohm)
    auxiliary_voltage = Float64.(auxiliary_voltage_v)
    previous_terminal = Float64.(previous_terminal_voltage_v)
    terminal = Float64.(terminal_voltage_v)
    size(inverse_inductance) == (state_count, state_count) &&
        length(offset) == state_count && length(resistance) == state_count &&
        length(auxiliary_voltage) == state_count || throw(DimensionMismatch(
            "independent machine trapezoidal state dimensions disagree",
        ))
    length(previous_terminal) == 4 && length(terminal) == 4 || throw(DimensionMismatch(
        "independent machine terminal voltage requires three phases and neutral",
    ))
    all(isfinite, previous_flux) && all(isfinite, inverse_inductance) &&
        all(isfinite, offset) && all(isfinite, resistance) &&
        all(isfinite, auxiliary_voltage) && all(isfinite, previous_terminal) &&
        all(isfinite, terminal) || throw(ArgumentError(
            "independent machine trapezoidal inputs must be finite",
        ))
    zero = Int(zero_index)
    d_index = Int(d_axis_index)
    q_index = Int(q_axis_index)
    pairs = Int(pole_pairs)
    step = Float64(timestep_s)
    tolerance_value = Float64(tolerance)
    iteration_limit = Int(maximum_iterations)
    pairs > 0 && step > 0.0 && tolerance_value > 0.0 && iteration_limit >= 2 ||
        throw(ArgumentError("independent machine numerical settings are invalid"))
    angle = Float64(electrical_angle_rad)
    speed = Float64(mechanical_speed_rad_s)
    input_map, output_map = _independent_machine_voltage_map(
        state_count,
        zero,
        d_index,
        q_index,
        angle,
    )
    speed_matrix = zeros(state_count, state_count)
    electrical_speed = pairs * speed
    speed_matrix[d_index, q_index] = electrical_speed
    speed_matrix[q_index, d_index] = -electrical_speed
    voltage_previous = input_map * previous_terminal + auxiliary_voltage
    voltage_current = input_map * terminal + auxiliary_voltage
    previous_evaluation = independent_machine_coenergy(
        previous_flux,
        inverse_inductance,
        offset;
        d_axis_index=d_index,
        q_axis_index=q_index,
        radial_coefficient_per_wb2_h,
        cross_coefficient_per_wb2_h,
    )
    previous_derivative = voltage_previous -
        resistance .* previous_evaluation.current_a + speed_matrix * previous_flux
    flux = previous_flux + step .* previous_derivative
    identity_state = Matrix{Float64}(I, state_count, state_count)
    residual_norm = Inf
    iterations = 0
    evaluation = previous_evaluation
    tangent = copy(identity_state)
    for iteration in 1:iteration_limit
        iterations = iteration
        evaluation = independent_machine_coenergy(
            flux,
            inverse_inductance,
            offset;
            d_axis_index=d_index,
            q_axis_index=q_index,
            radial_coefficient_per_wb2_h,
            cross_coefficient_per_wb2_h,
        )
        derivative = voltage_current - resistance .* evaluation.current_a +
            speed_matrix * flux
        residual = flux - previous_flux -
            0.5 * step .* (previous_derivative + derivative)
        residual_norm = maximum(abs, residual; init=0.0)
        tangent .= identity_state .- 0.5 * step .* (
            -Diagonal(resistance) * evaluation.current_flux_jacobian_per_h +
            speed_matrix
        )
        residual_norm <= tolerance_value * max(maximum(abs, flux; init=0.0), 1.0) &&
            break
        flux -= tangent \ residual
    end
    residual_norm <= tolerance_value * max(maximum(abs, flux; init=0.0), 1.0) ||
        throw(ArgumentError("independent machine trapezoidal step did not converge"))
    evaluation = independent_machine_coenergy(
        flux,
        inverse_inductance,
        offset;
        d_axis_index=d_index,
        q_axis_index=q_index,
        radial_coefficient_per_wb2_h,
        cross_coefficient_per_wb2_h,
    )
    tangent .= identity_state .- 0.5 * step .* (
        -Diagonal(resistance) * evaluation.current_flux_jacobian_per_h + speed_matrix
    )
    terminal_flux_sensitivity = tangent \ (0.5 * step .* input_map)
    terminal_current = output_map * evaluation.current_a
    terminal_jacobian = output_map * evaluation.current_flux_jacobian_per_h *
        terminal_flux_sensitivity
    torque = pairs * (
        flux[d_index] * evaluation.current_a[q_index] -
        flux[q_index] * evaluation.current_a[d_index]
    )
    copper_loss = dot(evaluation.current_a, resistance .* evaluation.current_a)
    return IndependentMachineElectricalState(
        flux,
        evaluation.current_a,
        terminal_current,
        terminal_jacobian,
        torque,
        evaluation.magnetic_coenergy_j,
        copper_loss,
        residual_norm,
        iterations,
    )
end

"""Independent explicit-trapezoidal multi-mass shaft update from incidence matrices."""
function independent_machine_shaft_step(
    previous_angle_rad,
    previous_speed_rad_s,
    inertia_kg_m2,
    self_damping_nm_s_per_rad,
    coupling_incidence,
    coupling_stiffness_nm_per_rad,
    coupling_damping_nm_s_per_rad,
    coupling_reference_twist_rad,
    external_torque_nm,
    timestep_s::Real,
)
    angle = Float64.(previous_angle_rad)
    speed = Float64.(previous_speed_rad_s)
    inertia = Float64.(inertia_kg_m2)
    self_damping = Float64.(self_damping_nm_s_per_rad)
    incidence = Matrix{Float64}(coupling_incidence)
    stiffness = Float64.(coupling_stiffness_nm_per_rad)
    coupling_damping = Float64.(coupling_damping_nm_s_per_rad)
    reference_twist = Float64.(coupling_reference_twist_rad)
    external_torque = Float64.(external_torque_nm)
    step = Float64(timestep_s)
    mass_count = length(angle)
    coupling_count = length(stiffness)
    length(speed) == mass_count && length(inertia) == mass_count &&
        length(self_damping) == mass_count && length(external_torque) == mass_count &&
        size(incidence) == (coupling_count, mass_count) &&
        length(coupling_damping) == coupling_count &&
        length(reference_twist) == coupling_count || throw(DimensionMismatch(
            "independent machine shaft dimensions disagree",
        ))
    all(isfinite, angle) && all(isfinite, speed) && all(isfinite, inertia) &&
        all(isfinite, self_damping) && all(isfinite, incidence) &&
        all(isfinite, stiffness) && all(isfinite, coupling_damping) &&
        all(isfinite, reference_twist) && all(isfinite, external_torque) &&
        isfinite(step) || throw(ArgumentError("independent shaft inputs must be finite"))
    all(>(0.0), inertia) && all(>=(0.0), self_damping) &&
        all(>(0.0), stiffness) && all(>=(0.0), coupling_damping) && step > 0.0 ||
        throw(ArgumentError("independent shaft passive values and timestep are invalid"))
    function derivative(theta, omega)
        twist = incidence * theta - reference_twist
        relative_speed = incidence * omega
        branch_torque = stiffness .* twist + coupling_damping .* relative_speed
        net_torque = external_torque - self_damping .* omega -
            transpose(incidence) * branch_torque
        acceleration = net_torque ./ inertia
        damping_loss = dot(self_damping, omega .^ 2) +
            dot(coupling_damping, relative_speed .^ 2)
        return omega, acceleration, branch_torque, damping_loss
    end
    first_derivative = derivative(angle, speed)
    predicted_angle = angle + step .* first_derivative[1]
    predicted_speed = speed + step .* first_derivative[2]
    second_derivative = derivative(predicted_angle, predicted_speed)
    accepted_angle = angle + 0.5 * step .* (
        first_derivative[1] + second_derivative[1]
    )
    accepted_speed = speed + 0.5 * step .* (
        first_derivative[2] + second_derivative[2]
    )
    branch_torque = 0.5 .* (first_derivative[3] + second_derivative[3])
    kinetic = 0.5 * dot(inertia, accepted_speed .^ 2)
    accepted_twist = incidence * accepted_angle - reference_twist
    elastic = 0.5 * dot(stiffness, accepted_twist .^ 2)
    previous_momentum = dot(inertia, speed)
    accepted_momentum = dot(inertia, accepted_speed)
    average_self_damping = self_damping .* (speed + accepted_speed) ./ 2.0
    expected_momentum_change = step * (sum(external_torque) - sum(average_self_damping))
    return IndependentMachineShaftState(
        accepted_angle,
        accepted_speed,
        branch_torque,
        kinetic,
        elastic,
        0.5 * (first_derivative[4] + second_derivative[4]),
        (accepted_momentum - previous_momentum) - expected_momentum_change,
    )
end

"""Independent exact sampled excitation/governor/stabilizer update."""
function independent_machine_control_step(
    previous::IndependentMachineControlState,
    terminal_voltage_v,
    mechanical_speed_rad_s::Real,
    sample_interval_s::Real,
    parameters,
)
    terminal = Float64.(terminal_voltage_v)
    length(terminal) == 4 || throw(DimensionMismatch(
        "independent machine control requires three phases and neutral",
    ))
    phase_to_neutral = terminal[1:3] .- terminal[4]
    sensed_voltage = sqrt(sum(abs2, phase_to_neutral) / 3.0)
    speed = Float64(mechanical_speed_rad_s)
    interval = Float64(sample_interval_s)
    interval > 0.0 || throw(ArgumentError("independent control interval must be positive"))
    speed_derivative = (speed - previous.sampled_speed_rad_s) / interval
    washout_decay = exp(-interval / parameters.stabilizer_washout_s)
    washout = washout_decay * previous.stabilizer_washout_state +
        (1.0 - washout_decay) * speed_derivative
    lead_input = parameters.stabilizer_gain * washout
    lag_decay = exp(-interval / parameters.stabilizer_lag_s)
    lead_fraction = parameters.stabilizer_lead_s / parameters.stabilizer_lag_s
    lead_lag = lag_decay * previous.stabilizer_lead_lag_state +
        (1.0 - lag_decay) * lead_fraction * lead_input
    excitation_target = parameters.base_field_voltage_v + parameters.excitation_gain * (
        parameters.voltage_reference_v - sensed_voltage + lead_lag
    )
    excitation_decay = exp(-interval / parameters.excitation_time_constant_s)
    unconstrained_excitation = excitation_decay * previous.excitation_state_v +
        (1.0 - excitation_decay) * excitation_target
    field_voltage = clamp(
        unconstrained_excitation,
        parameters.field_voltage_min_v,
        parameters.field_voltage_max_v,
    )
    speed_error = parameters.speed_reference_rad_s - speed
    droop_torque = parameters.governor_droop_rad_s_per_nm == 0.0 ? 0.0 :
        speed_error / parameters.governor_droop_rad_s_per_nm
    torque_target = parameters.base_mechanical_torque_nm + droop_torque
    governor_decay = exp(-interval / parameters.governor_time_constant_s)
    unconstrained_torque = governor_decay * previous.governor_state_nm +
        (1.0 - governor_decay) * torque_target
    torque = clamp(
        unconstrained_torque,
        parameters.torque_min_nm,
        parameters.torque_max_nm,
    )
    return IndependentMachineControlState(
        sensed_voltage,
        speed,
        field_voltage,
        torque,
        washout,
        lead_lag,
        field_voltage,
        torque,
        field_voltage != unconstrained_excitation,
        torque != unconstrained_torque,
    )
end

"""Solve a convex coenergy relation for flux at a specified winding current."""
function independent_machine_consistent_flux(
    target_current_a,
    inverse_inductance_per_h,
    permanent_flux_offset_wb;
    d_axis_index::Integer,
    q_axis_index::Integer,
    radial_coefficient_per_wb2_h::Real=0.0,
    cross_coefficient_per_wb2_h::Real=0.0,
    tolerance::Real=1.0e-12,
    maximum_iterations::Integer=24,
)
    target = Float64.(target_current_a)
    inverse_inductance = Matrix{Float64}(inverse_inductance_per_h)
    offset = Float64.(permanent_flux_offset_wb)
    flux = inverse_inductance \ target + offset
    residual_norm = Inf
    iterations = 0
    for iteration in 1:Int(maximum_iterations)
        iterations = iteration
        evaluation = independent_machine_coenergy(
            flux,
            inverse_inductance,
            offset;
            d_axis_index,
            q_axis_index,
            radial_coefficient_per_wb2_h,
            cross_coefficient_per_wb2_h,
        )
        residual = evaluation.current_a - target
        residual_norm = maximum(abs, residual; init=0.0)
        residual_norm <= Float64(tolerance) * max(maximum(abs, target; init=0.0), 1.0) &&
            return (; flux_wb=flux, residual_a=residual_norm, iterations)
        flux -= evaluation.current_flux_jacobian_per_h \ residual
    end
    throw(ArgumentError(
        "independent machine consistent-flux solve did not converge: residual=$(residual_norm)",
    ))
end

function independent_machine_power_balance(
    terminal_voltage_v,
    terminal_current_a,
    field_voltage_v::Real,
    field_current_a::Real,
    rotor_voltage_dq_v,
    rotor_current_dq_a,
    mechanical_torque_nm::Real,
    mechanical_speed_rad_s::Real,
    stored_energy_change_j::Real,
    dissipated_energy_j::Real,
    timestep_s::Real,
)
    terminal_voltage = Float64.(terminal_voltage_v)
    terminal_current = Float64.(terminal_current_a)
    rotor_voltage = Float64.(rotor_voltage_dq_v)
    rotor_current = Float64.(rotor_current_dq_a)
    length(terminal_voltage) == length(terminal_current) || throw(DimensionMismatch(
        "independent machine terminal power dimensions disagree",
    ))
    length(rotor_voltage) == length(rotor_current) || throw(DimensionMismatch(
        "independent machine rotor-port power dimensions disagree",
    ))
    step = Float64(timestep_s)
    step > 0.0 || throw(ArgumentError("independent machine power-balance step must be positive"))
    terminal_power = dot(terminal_voltage, terminal_current)
    field_power = Float64(field_voltage_v) * Float64(field_current_a)
    rotor_power = dot(rotor_voltage, rotor_current)
    mechanical_power = Float64(mechanical_torque_nm) * Float64(mechanical_speed_rad_s)
    supplied_energy = step * (terminal_power + field_power + rotor_power + mechanical_power)
    residual = Float64(stored_energy_change_j) -
        (supplied_energy - Float64(dissipated_energy_j))
    return (
        terminal_power_w=terminal_power,
        field_power_w=field_power,
        rotor_port_power_w=rotor_power,
        mechanical_power_w=mechanical_power,
        supplied_energy_j=supplied_energy,
        energy_residual_j=residual,
    )
end
