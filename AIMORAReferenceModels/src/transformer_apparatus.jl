export IndependentTransformerTerminalState,
       IndependentTransformerWidebandState,
       IndependentTransformerNetworkState,
       IndependentTellinenState,
       independent_transformer_connection,
       independent_transformer_switched_terminal_companion,
       independent_transformer_terminal_step,
       independent_transformer_sinusoidal_linear_state,
       independent_transformer_sinusoidal_terminal_state,
       independent_transformer_sinusoidal_network_state,
       independent_transformer_residual_flux_equilibrium,
       independent_transformer_magnetic_linear_response,
       independent_transformer_piecewise_magnetic_endpoint,
       independent_transformer_dynamic_core_loss_companion,
       independent_transformer_wideband_step,
       independent_transformer_network_step,
       independent_tellinen_state,
       independent_tellinen_trial

"""Independently eliminate open apparatus ports and map an ideal terminal transform.

The supplied physical companion is `i_a = Y_a*v_a + h_a`. Closed apparatus
ports receive `v_a = T*v_network`; open ports satisfy exactly zero apparatus
current. Network-side currents use `T'` and an optional passive fault/grounding
admittance. This reference owns no production event, stamp, history, or solver
code.
"""
function independent_transformer_switched_terminal_companion(
    apparatus_admittance_s,
    apparatus_history_current_a,
    terminal_closed,
    terminal_transform,
    terminal_fault_admittance_s,
    network_terminal_voltage_v,
)
    admittance = Matrix{Float64}(apparatus_admittance_s)
    count = size(admittance, 1)
    size(admittance, 2) == count || throw(DimensionMismatch(
        "independent transformer apparatus admittance must be square",
    ))
    history = Float64.(apparatus_history_current_a)
    length(history) == count || throw(DimensionMismatch(
        "independent transformer apparatus history count is incompatible",
    ))
    closed_mask = BitVector(terminal_closed)
    length(closed_mask) == count || throw(DimensionMismatch(
        "independent transformer terminal switch count is incompatible",
    ))
    transform = Matrix{Float64}(terminal_transform)
    fault_admittance = Matrix{Float64}(terminal_fault_admittance_s)
    size(transform) == (count, count) || throw(DimensionMismatch(
        "independent transformer terminal transform is incompatible",
    ))
    size(fault_admittance) == (count, count) || throw(DimensionMismatch(
        "independent transformer fault admittance is incompatible",
    ))
    network_voltage = Float64.(network_terminal_voltage_v)
    length(network_voltage) == count || throw(DimensionMismatch(
        "independent transformer network voltage count is incompatible",
    ))
    all(isfinite, admittance) && all(isfinite, history) &&
        all(isfinite, transform) && all(isfinite, fault_admittance) &&
        all(isfinite, network_voltage) || throw(ArgumentError(
            "independent transformer switched companion inputs must be finite",
        ))
    closed = findall(closed_mask)
    open = findall(.!closed_mask)
    apparatus_voltage = zeros(count)
    isempty(closed) || (apparatus_voltage[closed] .=
        transform[closed, :] * network_voltage)
    open_inverse = zeros(length(open), length(open))
    if !isempty(open)
        open_matrix = admittance[open, open]
        decomposition = svd(open_matrix)
        largest = maximum(decomposition.S; init=0.0)
        threshold = max(size(open_matrix)...) * eps(Float64) * max(largest, 1.0)
        open_inverse .= decomposition.V * Diagonal(
            map(value -> value > threshold ? inv(value) : 0.0, decomposition.S),
        ) * transpose(decomposition.U)
        apparatus_voltage[open] .= -open_inverse * (
            admittance[open, closed] * apparatus_voltage[closed] .+ history[open]
        )
    end
    apparatus_current = admittance * apparatus_voltage .+ history
    closed_transform = transform[closed, :]
    reduced_admittance = isempty(closed) ? zeros(count, count) :
        transpose(closed_transform) * (
            admittance[closed, closed] .-
            admittance[closed, open] * open_inverse * admittance[open, closed]
        ) * closed_transform
    network_admittance = reduced_admittance .+ fault_admittance
    network_current = fault_admittance * network_voltage
    isempty(closed) || (network_current .+=
        transpose(closed_transform) * apparatus_current[closed])
    open_residual = maximum(abs, apparatus_current[open]; init=0.0)
    return (
        apparatus_terminal_voltage_v=apparatus_voltage,
        apparatus_terminal_current_a=apparatus_current,
        network_terminal_current_a=network_current,
        network_terminal_admittance_s=network_admittance,
        open_terminal_current_residual_a=open_residual,
        conjugate_power_residual_w=dot(network_voltage, network_current) -
            dot(apparatus_voltage, apparatus_current) -
            dot(network_voltage, fault_admittance * network_voltage),
    )
end

function _independent_transformer_square_matrix(values, dimension::Int, label::AbstractString)
    matrix = Matrix{Float64}(values)
    size(matrix) == (dimension, dimension) || throw(DimensionMismatch(
        "$label must be $dimension by $dimension",
    ))
    all(isfinite, matrix) || throw(ArgumentError("$label must be finite"))
    return matrix
end

"""Evaluate an independent energy-consistent classical/excess magnetic-loss companion.

The returned endpoint fields satisfy the trapezoidal identity that their average
with the previous endpoint equals the dissipative midpoint field. Energy is
computed independently from midpoint `H*dB` work over the supplied core volume.
"""
function independent_transformer_dynamic_core_loss_companion(
    previous_flux_density_t::Real,
    current_flux_density_t::Real,
    timestep_s::Real,
    classical_eddy_coefficient_a_s_per_m_t::Real,
    excess_loss_coefficient_a_sqrt_s_per_m_sqrt_t::Real;
    previous_classical_field_a_per_m::Real=0.0,
    previous_excess_field_a_per_m::Real=0.0,
    excess_rate_regularization_t_per_s::Real=1.0e-9,
    core_volume_m3::Real=1.0,
)
    previous_flux_density = Float64(previous_flux_density_t)
    current_flux_density = Float64(current_flux_density_t)
    timestep = Float64(timestep_s)
    classical_coefficient = Float64(classical_eddy_coefficient_a_s_per_m_t)
    excess_coefficient = Float64(excess_loss_coefficient_a_sqrt_s_per_m_sqrt_t)
    previous_classical_field = Float64(previous_classical_field_a_per_m)
    previous_excess_field = Float64(previous_excess_field_a_per_m)
    regularization = Float64(excess_rate_regularization_t_per_s)
    volume = Float64(core_volume_m3)
    all(isfinite, (
        previous_flux_density,
        current_flux_density,
        timestep,
        classical_coefficient,
        excess_coefficient,
        previous_classical_field,
        previous_excess_field,
        regularization,
        volume,
    )) || throw(ArgumentError("independent dynamic core-loss inputs must be finite"))
    timestep > 0.0 && classical_coefficient >= 0.0 && excess_coefficient >= 0.0 &&
        regularization > 0.0 && volume > 0.0 || throw(ArgumentError(
            "independent dynamic core-loss timestep, regularization, and volume must be positive and coefficients nonnegative",
        ))
    rate = (current_flux_density - previous_flux_density) / timestep
    regularized_rate_squared = rate^2 + regularization^2
    fourth_root = regularized_rate_squared^0.25
    midpoint_classical_field = classical_coefficient * rate
    midpoint_excess_field = excess_coefficient * rate / fourth_root
    endpoint_classical_field =
        2.0 * midpoint_classical_field - previous_classical_field
    endpoint_excess_field = 2.0 * midpoint_excess_field - previous_excess_field
    classical_energy = volume * timestep * midpoint_classical_field * rate
    excess_energy = volume * timestep * midpoint_excess_field * rate
    return (
        flux_density_rate_t_per_s=rate,
        endpoint_classical_field_a_per_m=endpoint_classical_field,
        endpoint_excess_field_a_per_m=endpoint_excess_field,
        midpoint_classical_field_a_per_m=midpoint_classical_field,
        midpoint_excess_field_a_per_m=midpoint_excess_field,
        classical_loss_energy_j=classical_energy,
        excess_loss_energy_j=excess_energy,
        total_loss_energy_j=classical_energy + excess_energy,
    )
end

"""Apply an independently supplied winding incidence and prove conjugate electrical power."""
function independent_transformer_connection(incidence, node_voltage_v, coil_current_a)
    connection = Matrix{Float64}(incidence)
    node_voltage = Float64.(node_voltage_v)
    coil_current = Float64.(coil_current_a)
    size(connection) == (length(node_voltage), length(coil_current)) ||
        throw(DimensionMismatch(
            "independent transformer connection dimensions disagree",
        ))
    all(isfinite, connection) && all(isfinite, node_voltage) &&
        all(isfinite, coil_current) || throw(ArgumentError(
            "independent transformer connection values must be finite",
        ))
    coil_voltage = transpose(connection) * node_voltage
    terminal_current = connection * coil_current
    return (
        coil_voltage_v=coil_voltage,
        terminal_current_a=terminal_current,
        node_power_w=dot(node_voltage, terminal_current),
        coil_power_w=dot(coil_voltage, coil_current),
        power_residual_w=dot(node_voltage, terminal_current) -
            dot(coil_voltage, coil_current),
    )
end

"""Accepted state for the independent reciprocal transformer R-L plus parallel C-G recurrence."""
struct IndependentTransformerTerminalState
    coil_current_a::Vector{Float64}
    capacitor_current_a::Vector{Float64}
    coil_voltage_v::Vector{Float64}
    terminal_voltage_v::Vector{Float64}
    terminal_current_a::Vector{Float64}
    supplied_energy_j::Float64
    winding_loss_energy_j::Float64
    dielectric_loss_energy_j::Float64
    stored_magnetic_energy_j::Float64
    stored_electric_energy_j::Float64
    accepted_step_count::Int
end

function IndependentTransformerTerminalState(coil_count::Integer, terminal_count::Integer)
    coils = Int(coil_count)
    terminals = Int(terminal_count)
    coils > 0 && terminals > 0 || throw(ArgumentError(
        "independent transformer state dimensions must be positive",
    ))
    return IndependentTransformerTerminalState(
        zeros(coils),
        zeros(coils),
        zeros(coils),
        zeros(terminals),
        zeros(terminals),
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0,
    )
end

"""Advance the independent complete coupled terminal companion by one endpoint-trapezoidal step."""
function independent_transformer_terminal_step(
    resistance_ohm,
    inductance_h,
    capacitance_f,
    conductance_s,
    incidence,
    accepted::IndependentTransformerTerminalState,
    terminal_voltage_v,
    timestep_s::Real,
)
    connection = Matrix{Float64}(incidence)
    coil_count = size(connection, 2)
    terminal_count = size(connection, 1)
    length(accepted.coil_current_a) == coil_count &&
        length(accepted.terminal_voltage_v) == terminal_count ||
        throw(DimensionMismatch("independent transformer accepted state is incompatible"))
    resistance = _independent_transformer_square_matrix(
        resistance_ohm,
        coil_count,
        "independent transformer resistance",
    )
    inductance = _independent_transformer_square_matrix(
        inductance_h,
        coil_count,
        "independent transformer inductance",
    )
    capacitance = _independent_transformer_square_matrix(
        capacitance_f,
        coil_count,
        "independent transformer capacitance",
    )
    conductance = _independent_transformer_square_matrix(
        conductance_s,
        coil_count,
        "independent transformer conductance",
    )
    timestep = Float64(timestep_s)
    isfinite(timestep) && timestep > 0.0 || throw(ArgumentError(
        "independent transformer timestep must be finite and positive",
    ))
    terminal_voltage = Float64.(terminal_voltage_v)
    length(terminal_voltage) == terminal_count && all(isfinite, terminal_voltage) ||
        throw(DimensionMismatch(
            "independent transformer terminal voltage is incompatible",
        ))
    alpha = 2.0 / timestep
    companion_impedance = resistance + alpha .* inductance
    coil_voltage = transpose(connection) * terminal_voltage
    history_voltage = accepted.coil_voltage_v +
        (alpha .* inductance - resistance) * accepted.coil_current_a
    coil_current = companion_impedance \ (coil_voltage + history_voltage)
    capacitor_current = alpha .* capacitance *
        (coil_voltage - accepted.coil_voltage_v) - accepted.capacitor_current_a
    total_coil_current = coil_current + capacitor_current + conductance * coil_voltage
    terminal_current = connection * total_coil_current
    coil_jacobian = companion_impedance \ Matrix{Float64}(I, coil_count, coil_count) +
        alpha .* capacitance + conductance
    terminal_jacobian = connection * coil_jacobian * transpose(connection)
    average_terminal_voltage = 0.5 .* (
        accepted.terminal_voltage_v + terminal_voltage
    )
    average_terminal_current = 0.5 .* (
        accepted.terminal_current_a + terminal_current
    )
    average_coil_current = 0.5 .* (accepted.coil_current_a + coil_current)
    average_coil_voltage = 0.5 .* (accepted.coil_voltage_v + coil_voltage)
    supplied_energy = accepted.supplied_energy_j + timestep *
        dot(average_terminal_voltage, average_terminal_current)
    winding_loss = accepted.winding_loss_energy_j + timestep *
        dot(average_coil_current, resistance * average_coil_current)
    dielectric_loss = accepted.dielectric_loss_energy_j + timestep *
        dot(average_coil_voltage, conductance * average_coil_voltage)
    stored_magnetic = 0.5 * dot(coil_current, inductance * coil_current)
    stored_electric = 0.5 * dot(coil_voltage, capacitance * coil_voltage)
    next_state = IndependentTransformerTerminalState(
        coil_current,
        capacitor_current,
        coil_voltage,
        terminal_voltage,
        terminal_current,
        supplied_energy,
        winding_loss,
        dielectric_loss,
        stored_magnetic,
        stored_electric,
        accepted.accepted_step_count + 1,
    )
    return (
        state=next_state,
        terminal_jacobian_s=terminal_jacobian,
        energy_residual_j=supplied_energy - winding_loss - dielectric_loss -
            stored_magnetic - stored_electric,
    )
end

function _independent_transformer_sinusoidal_frequencies(
    frequency_hz::Real,
    timestep_s::Real,
)
    frequency = Float64(frequency_hz)
    timestep = Float64(timestep_s)
    isfinite(frequency) && frequency > 0.0 && isfinite(timestep) && timestep > 0.0 ||
        throw(ArgumentError(
            "independent transformer sinusoidal frequency and timestep must be positive",
        ))
    physical_angular_frequency = 2.0 * pi * frequency
    half_step_angle = 0.5 * physical_angular_frequency * timestep
    abs(half_step_angle) < 0.5 * pi || throw(DomainError(
        half_step_angle,
        "independent transformer sinusoid reaches the trapezoidal Nyquist boundary",
    ))
    return physical_angular_frequency,
        (2.0 / timestep) * tan(half_step_angle)
end

"""Solve one independent trapezoidal-periodic LTI state from a supplied input phasor."""
function independent_transformer_sinusoidal_linear_state(
    state_matrix_per_s,
    input_matrix,
    input_phasor,
    frequency_hz::Real,
    timestep_s::Real,
)
    state_matrix = Matrix{Float64}(state_matrix_per_s)
    input = Matrix{Float64}(input_matrix)
    forcing = ComplexF64.(input_phasor)
    state_count = size(state_matrix, 1)
    size(state_matrix) == (state_count, state_count) &&
        size(input, 1) == state_count && size(input, 2) == length(forcing) ||
        throw(DimensionMismatch(
            "independent transformer sinusoidal state-space dimensions disagree",
        ))
    _, discrete_frequency = _independent_transformer_sinusoidal_frequencies(
        frequency_hz,
        timestep_s,
    )
    state_phasor = (
        im * discrete_frequency .* Matrix{ComplexF64}(I, state_count, state_count) .-
        ComplexF64.(state_matrix)
    ) \ (ComplexF64.(input) * forcing)
    residual = im * discrete_frequency .* state_phasor .-
        ComplexF64.(state_matrix) * state_phasor .-
        ComplexF64.(input) * forcing
    return (
        state_phasor=state_phasor,
        state=real.(state_phasor),
        discrete_derivative=real.(im * discrete_frequency .* state_phasor),
        residual=maximum(abs, residual; init=0.0),
        discrete_angular_frequency_rad_per_s=discrete_frequency,
    )
end

"""Construct an independent periodic coupled R-L plus parallel C-G terminal state."""
function independent_transformer_sinusoidal_terminal_state(
    resistance_ohm,
    inductance_h,
    capacitance_f,
    conductance_s,
    incidence,
    terminal_voltage_phasor,
    frequency_hz::Real,
    timestep_s::Real,
)
    connection = Matrix{Float64}(incidence)
    terminal_voltage = ComplexF64.(terminal_voltage_phasor)
    coil_count = size(connection, 2)
    size(connection, 1) == length(terminal_voltage) || throw(DimensionMismatch(
        "independent transformer sinusoidal terminal order is incompatible",
    ))
    resistance = _independent_transformer_square_matrix(
        resistance_ohm,
        coil_count,
        "independent sinusoidal transformer resistance",
    )
    inductance = _independent_transformer_square_matrix(
        inductance_h,
        coil_count,
        "independent sinusoidal transformer inductance",
    )
    capacitance = _independent_transformer_square_matrix(
        capacitance_f,
        coil_count,
        "independent sinusoidal transformer capacitance",
    )
    conductance = _independent_transformer_square_matrix(
        conductance_s,
        coil_count,
        "independent sinusoidal transformer conductance",
    )
    _, discrete_frequency = _independent_transformer_sinusoidal_frequencies(
        frequency_hz,
        timestep_s,
    )
    coil_voltage = transpose(connection) * terminal_voltage
    coil_current = (
        ComplexF64.(resistance) .+
        im * discrete_frequency .* ComplexF64.(inductance)
    ) \ coil_voltage
    capacitor_current =
        im * discrete_frequency .* (ComplexF64.(capacitance) * coil_voltage)
    total_coil_current = coil_current .+ capacitor_current .+
        ComplexF64.(conductance) * coil_voltage
    terminal_current = ComplexF64.(connection) * total_coil_current
    residual = coil_voltage .-
        (
            ComplexF64.(resistance) .+
            im * discrete_frequency .* ComplexF64.(inductance)
        ) * coil_current
    return (
        coil_voltage_phasor=coil_voltage,
        coil_current_phasor=coil_current,
        capacitor_current_phasor=capacitor_current,
        terminal_current_phasor=terminal_current,
        electrical_residual_v=maximum(abs, residual; init=0.0),
        discrete_angular_frequency_rad_per_s=discrete_frequency,
    )
end

"""Solve an independent physical R-L-C-G graph at its trapezoidal sinusoidal frequency."""
function independent_transformer_sinusoidal_network_state(
    branch_incidence,
    branch_resistance_ohm,
    branch_inductance_h,
    capacitance_f,
    conductance_s,
    external_node_indices,
    terminal_voltage_phasor,
    frequency_hz::Real,
    timestep_s::Real,
)
    capacitance = Matrix{Float64}(capacitance_f)
    conductance = Matrix{Float64}(conductance_s)
    node_count = size(capacitance, 1)
    size(capacitance) == (node_count, node_count) &&
        size(conductance) == (node_count, node_count) || throw(DimensionMismatch(
            "independent sinusoidal network shunt matrices disagree",
        ))
    external = Int.(external_node_indices)
    internal = setdiff(collect(1:node_count), external)
    terminal_voltage = ComplexF64.(terminal_voltage_phasor)
    length(terminal_voltage) == length(external) || throw(DimensionMismatch(
        "independent sinusoidal network terminal voltage is incompatible",
    ))
    _, discrete_frequency = _independent_transformer_sinusoidal_frequencies(
        frequency_hz,
        timestep_s,
    )
    nodal_admittance = ComplexF64.(conductance) .+
        im * discrete_frequency .* ComplexF64.(capacitance)
    branch_admittance = Matrix{ComplexF64}[]
    for index in eachindex(branch_incidence)
        incidence = Matrix{Float64}(branch_incidence[index])
        resistance = Matrix{Float64}(branch_resistance_ohm[index])
        inductance = Matrix{Float64}(branch_inductance_h[index])
        admittance = inv(
            ComplexF64.(resistance) .+
            im * discrete_frequency .* ComplexF64.(inductance)
        )
        nodal_admittance .+= ComplexF64.(incidence) * admittance *
            transpose(ComplexF64.(incidence))
        push!(branch_admittance, admittance)
    end
    represented_voltage = zeros(ComplexF64, node_count)
    represented_voltage[external] .= terminal_voltage
    isempty(internal) || (represented_voltage[internal] .=
        -(nodal_admittance[internal, internal] \
          (nodal_admittance[internal, external] * terminal_voltage)))
    branch_voltage = Vector{ComplexF64}[]
    branch_current = Vector{ComplexF64}[]
    for index in eachindex(branch_incidence)
        voltage = transpose(ComplexF64.(branch_incidence[index])) *
            represented_voltage
        push!(branch_voltage, voltage)
        push!(branch_current, branch_admittance[index] * voltage)
    end
    nodal_current = nodal_admittance * represented_voltage
    return (
        represented_node_voltage_phasor=represented_voltage,
        branch_current_phasor=branch_current,
        branch_voltage_phasor=branch_voltage,
        capacitor_current_phasor=
            im * discrete_frequency .* (ComplexF64.(capacitance) * represented_voltage),
        terminal_current_phasor=nodal_current[external],
        internal_kcl_residual_a=maximum(abs, nodal_current[internal]; init=0.0),
        discrete_angular_frequency_rad_per_s=discrete_frequency,
    )
end

"""Project and verify an independently supplied fixed branch-flux equilibrium."""
function independent_transformer_residual_flux_equilibrium(
    magnetic_incidence,
    winding_turns,
    requested_branch_flux_wb,
    branch_mmf_drop_at,
    winding_current_a;
    projection_tolerance_wb::Real,
)
    incidence = Matrix{Float64}(magnetic_incidence)
    turns = Matrix{Float64}(winding_turns)
    requested_flux = Float64.(requested_branch_flux_wb)
    branch_mmf = Float64.(branch_mmf_drop_at)
    winding_current = Float64.(winding_current_a)
    size(incidence, 2) == length(requested_flux) == length(branch_mmf) &&
        size(turns) == (length(requested_flux), length(winding_current)) ||
        throw(DimensionMismatch(
            "independent residual-flux equilibrium dimensions disagree",
        ))
    correction = transpose(incidence) * (
        (incidence * transpose(incidence)) \ (incidence * requested_flux)
    )
    maximum_correction = maximum(abs, correction; init=0.0)
    maximum_correction <= Float64(projection_tolerance_wb) || throw(DomainError(
        maximum_correction,
        "independent residual-flux projection exceeds its declared tolerance",
    ))
    projected_flux = requested_flux - correction
    right_hand_side = turns * winding_current - branch_mmf
    magnetic_potential = (incidence * transpose(incidence)) \
        (incidence * right_hand_side)
    constitutive_residual = branch_mmf + transpose(incidence) * magnetic_potential -
        turns * winding_current
    return (
        projected_branch_flux_wb=projected_flux,
        projection_correction_wb=maximum_correction,
        magnetic_node_potential_at=magnetic_potential,
        continuity_residual_wb=
            maximum(abs, incidence * projected_flux; init=0.0),
        constitutive_residual_at=
            maximum(abs, constitutive_residual; init=0.0),
    )
end

"""Solve the independent linear magnetic graph KKT equations from branch reluctances."""
function independent_transformer_magnetic_linear_response(
    magnetic_incidence,
    winding_turns,
    branch_reluctance_at_per_wb,
    winding_current_a,
)
    incidence = Matrix{Float64}(magnetic_incidence)
    turns = Matrix{Float64}(winding_turns)
    reluctance = Float64.(branch_reluctance_at_per_wb)
    current = Float64.(winding_current_a)
    branch_count = size(incidence, 2)
    node_count = size(incidence, 1)
    length(reluctance) == branch_count && size(turns, 1) == branch_count &&
        size(turns, 2) == length(current) || throw(DimensionMismatch(
            "independent transformer magnetic graph dimensions disagree",
        ))
    all(value -> isfinite(value) && value > 0.0, reluctance) ||
        throw(ArgumentError(
            "independent transformer branch reluctances must be positive",
        ))
    system = [
        Diagonal(reluctance) transpose(incidence)
        incidence zeros(Float64, node_count, node_count)
    ]
    solution = system \ vcat(turns * current, zeros(node_count))
    branch_flux = solution[1:branch_count]
    magnetic_potential = solution[(branch_count + 1):end]
    branch_mmf = reluctance .* branch_flux
    return (
        branch_flux_wb=branch_flux,
        magnetic_node_potential_at=magnetic_potential,
        branch_mmf_drop_at=branch_mmf,
        winding_flux_linkage_wb_turn=transpose(turns) * branch_flux,
        stored_energy_j=0.5 * dot(branch_flux, branch_mmf),
        continuity_residual_wb=maximum(abs, incidence * branch_flux; init=0.0),
        constitutive_residual_at=maximum(
            abs,
            branch_mmf + transpose(incidence) * magnetic_potential - turns * current;
            init=0.0,
        ),
    )
end

function _independent_piecewise_value_and_slope(x_grid, y_grid, x::Float64)
    first(x_grid) <= x <= last(x_grid) || throw(DomainError(
        x,
        "independent transformer piecewise evaluation is outside its domain",
    ))
    index = x == last(x_grid) ? length(x_grid) - 1 : searchsortedlast(x_grid, x)
    index = clamp(index, 1, length(x_grid) - 1)
    slope = (y_grid[index + 1] - y_grid[index]) /
        (x_grid[index + 1] - x_grid[index])
    return y_grid[index] + slope * (x - x_grid[index]), slope
end

"""Solve an independent piecewise-linear nonlinear magnetic endpoint for fixed winding current."""
function independent_transformer_piecewise_magnetic_endpoint(
    magnetic_incidence,
    winding_turns,
    branch_length_m,
    branch_area_m2,
    branch_air_gap_m,
    flux_density_grids_t,
    field_strength_grids_a_per_m,
    winding_current_a;
    branch_air_gap_effective_area_factor=ones(length(branch_air_gap_m)),
    relative_tolerance::Real=1.0e-11,
    maximum_iterations::Integer=40,
)
    incidence = Matrix{Float64}(magnetic_incidence)
    turns = Matrix{Float64}(winding_turns)
    length_m = Float64.(branch_length_m)
    area_m2 = Float64.(branch_area_m2)
    gap_m = Float64.(branch_air_gap_m)
    gap_area_factor = Float64.(branch_air_gap_effective_area_factor)
    current = Float64.(winding_current_a)
    branch_count = size(incidence, 2)
    node_count = size(incidence, 1)
    all(length(values) == branch_count for values in (
        length_m,
        area_m2,
        gap_m,
        gap_area_factor,
        flux_density_grids_t,
        field_strength_grids_a_per_m,
    )) || throw(DimensionMismatch(
        "independent nonlinear magnetic branch data dimensions disagree",
    ))
    all(isfinite, gap_area_factor) && all(>=(1.0), gap_area_factor) ||
        throw(ArgumentError(
            "independent nonlinear magnetic gap-area factors must be finite and at least one",
        ))
    all(
        branch -> gap_m[branch] > 0.0 || gap_area_factor[branch] == 1.0,
        1:branch_count,
    ) || throw(ArgumentError(
        "independent magnetic branches without gaps require unit gap-area factor",
    ))
    flux = zeros(branch_count)
    potential = zeros(node_count)
    mmf = zeros(branch_count)
    differential = zeros(branch_count)
    tolerance = Float64(relative_tolerance)
    vacuum_permeability = 4.0e-7 * pi
    for iteration in 1:Int(maximum_iterations)
        for branch in 1:branch_count
            density = flux[branch] / area_m2[branch]
            field, reluctivity = _independent_piecewise_value_and_slope(
                flux_density_grids_t[branch],
                field_strength_grids_a_per_m[branch],
                abs(density),
            )
            field = copysign(field, density)
            core_length = length_m[branch] - gap_m[branch]
            gap_density = density / gap_area_factor[branch]
            mmf[branch] = core_length * field +
                gap_m[branch] * gap_density / vacuum_permeability
            differential[branch] =
                core_length * reluctivity / area_m2[branch] +
                gap_m[branch] / (
                    vacuum_permeability * area_m2[branch] * gap_area_factor[branch]
                )
        end
        constitutive = mmf + transpose(incidence) * potential - turns * current
        continuity = incidence * flux
        scale = max(maximum(abs, turns * current; init=0.0), 1.0)
        if maximum(abs, constitutive; init=0.0) <= tolerance * scale &&
           maximum(abs, continuity; init=0.0) <= tolerance * 1.0e-6
            return (
                branch_flux_wb=copy(flux),
                branch_mmf_drop_at=copy(mmf),
                magnetic_node_potential_at=copy(potential),
                differential_reluctance_at_per_wb=copy(differential),
                iterations=iteration,
                constitutive_residual_at=maximum(abs, constitutive; init=0.0),
                continuity_residual_wb=maximum(abs, continuity; init=0.0),
            )
        end
        jacobian = [
            Diagonal(differential) transpose(incidence)
            incidence zeros(Float64, node_count, node_count)
        ]
        correction = -(jacobian \ vcat(constitutive, continuity))
        flux .+= correction[1:branch_count]
        potential .+= correction[(branch_count + 1):end]
    end
    throw(ArgumentError("independent nonlinear magnetic endpoint did not converge"))
end

struct IndependentTransformerWidebandState
    rational_state::Vector{Float64}
    terminal_voltage_v::Vector{Float64}
    terminal_current_a::Vector{Float64}
    supplied_energy_j::Float64
    dissipated_energy_j::Float64
    stored_energy_j::Float64
    accepted_step_count::Int
end

function IndependentTransformerWidebandState(state_count::Integer, port_count::Integer)
    return IndependentTransformerWidebandState(
        zeros(Float64, Int(state_count)),
        zeros(Float64, Int(port_count)),
        zeros(Float64, Int(port_count)),
        0.0,
        0.0,
        0.0,
        0,
    )
end

"""Advance a certified positive-real admittance independently by a bilinear endpoint step."""
function independent_transformer_wideband_step(
    state_matrix_per_s,
    input_matrix,
    output_matrix_s_per_s,
    direct_admittance_s,
    storage_matrix_j,
    dissipation_matrix_j_per_s,
    accepted::IndependentTransformerWidebandState,
    terminal_voltage_v,
    timestep_s::Real,
)
    state_matrix = Matrix{Float64}(state_matrix_per_s)
    input = Matrix{Float64}(input_matrix)
    output = Matrix{Float64}(output_matrix_s_per_s)
    direct = Matrix{Float64}(direct_admittance_s)
    storage = Matrix{Float64}(storage_matrix_j)
    dissipation = Matrix{Float64}(dissipation_matrix_j_per_s)
    timestep = Float64(timestep_s)
    voltage = Float64.(terminal_voltage_v)
    state_count = size(state_matrix, 1)
    port_count = length(voltage)
    identity_state = Matrix{Float64}(I, state_count, state_count)
    alpha = 2.0 / timestep
    solve_matrix = alpha .* identity_state - state_matrix
    transition = solve_matrix \ (alpha .* identity_state + state_matrix)
    endpoint_input = solve_matrix \ input
    rational_state = transition * accepted.rational_state +
        endpoint_input * (voltage + accepted.terminal_voltage_v)
    current = output * rational_state + direct * voltage
    jacobian = direct + output * endpoint_input
    average_state = 0.5 .* (accepted.rational_state + rational_state)
    average_voltage = 0.5 .* (accepted.terminal_voltage_v + voltage)
    average_current = 0.5 .* (accepted.terminal_current_a + current)
    supplied_increment = timestep * dot(average_voltage, average_current)
    loss_increment = timestep * (
        0.5 * dot(average_state, dissipation * average_state) +
        dot(average_voltage, direct * average_voltage)
    )
    stored_energy = 0.5 * dot(rational_state, storage * rational_state)
    next_state = IndependentTransformerWidebandState(
        rational_state,
        voltage,
        current,
        accepted.supplied_energy_j + supplied_increment,
        accepted.dissipated_energy_j + loss_increment,
        stored_energy,
        accepted.accepted_step_count + 1,
    )
    return (
        state=next_state,
        terminal_jacobian_s=jacobian,
        energy_residual_j=supplied_increment -
            (stored_energy - accepted.stored_energy_j) - loss_increment,
        port_count,
    )
end

struct IndependentTransformerNetworkState
    represented_node_voltage_v::Vector{Float64}
    branch_current_a::Vector{Vector{Float64}}
    branch_voltage_v::Vector{Vector{Float64}}
    capacitor_current_a::Vector{Float64}
end

function IndependentTransformerNetworkState(node_count::Integer, branch_widths)
    nodes = Int(node_count)
    widths = Int.(branch_widths)
    return IndependentTransformerNetworkState(
        zeros(nodes),
        [zeros(width) for width in widths],
        [zeros(width) for width in widths],
        zeros(nodes),
    )
end

"""Condense one independently supplied coupled R-L-C-G graph to its external terminals."""
function independent_transformer_network_step(
    branch_incidence,
    branch_resistance_ohm,
    branch_inductance_h,
    capacitance_f,
    conductance_s,
    external_node_indices,
    accepted::IndependentTransformerNetworkState,
    terminal_voltage_v,
    timestep_s::Real,
)
    node_count = length(accepted.represented_node_voltage_v)
    external = Int.(external_node_indices)
    internal = setdiff(collect(1:node_count), external)
    timestep = Float64(timestep_s)
    alpha = 2.0 / timestep
    nodal_admittance = Matrix{Float64}(conductance_s) +
        alpha .* Matrix{Float64}(capacitance_f)
    nodal_history = -accepted.capacitor_current_a -
        alpha .* Matrix{Float64}(capacitance_f) *
        accepted.represented_node_voltage_v
    branch_conductance = Matrix{Float64}[]
    branch_history = Vector{Float64}[]
    for index in eachindex(branch_incidence)
        incidence = Matrix{Float64}(branch_incidence[index])
        resistance = Matrix{Float64}(branch_resistance_ohm[index])
        inductance = Matrix{Float64}(branch_inductance_h[index])
        conductance = (resistance + alpha .* inductance) \
            Matrix{Float64}(I, size(resistance)...)
        history_voltage = accepted.branch_voltage_v[index] +
            (alpha .* inductance - resistance) * accepted.branch_current_a[index]
        history = conductance * history_voltage
        nodal_admittance .+= incidence * conductance * transpose(incidence)
        nodal_history .+= incidence * history
        push!(branch_conductance, conductance)
        push!(branch_history, history)
    end
    terminal_voltage = Float64.(terminal_voltage_v)
    represented_voltage = zeros(node_count)
    represented_voltage[external] .= terminal_voltage
    if !isempty(internal)
        represented_voltage[internal] .= nodal_admittance[internal, internal] \ -(
            nodal_admittance[internal, external] * terminal_voltage +
            nodal_history[internal]
        )
    end
    terminal_current = (nodal_admittance * represented_voltage + nodal_history)[external]
    if isempty(internal)
        terminal_jacobian = nodal_admittance[external, external]
    else
        terminal_jacobian = nodal_admittance[external, external] -
            nodal_admittance[external, internal] *
            (nodal_admittance[internal, internal] \
             nodal_admittance[internal, external])
    end
    branch_current = Vector{Float64}[]
    branch_voltage = Vector{Float64}[]
    for index in eachindex(branch_incidence)
        voltage = transpose(Matrix{Float64}(branch_incidence[index])) *
            represented_voltage
        current = branch_conductance[index] * voltage + branch_history[index]
        push!(branch_voltage, voltage)
        push!(branch_current, current)
    end
    capacitance = Matrix{Float64}(capacitance_f)
    capacitor_current = alpha .* capacitance *
        (represented_voltage - accepted.represented_node_voltage_v) -
        accepted.capacitor_current_a
    next_state = IndependentTransformerNetworkState(
        represented_voltage,
        branch_current,
        branch_voltage,
        capacitor_current,
    )
    internal_residual = nodal_admittance * represented_voltage + nodal_history
    return (
        state=next_state,
        terminal_current_a=terminal_current,
        terminal_jacobian_s=terminal_jacobian,
        internal_kcl_residual_a=maximum(abs, internal_residual[internal]; init=0.0),
    )
end

struct IndependentTellinenState
    flux_density_t::Float64
    field_strength_a_per_m::Float64
    direction::Int
    reversal_count::Int
end

function independent_tellinen_state(
    field_strength_a_per_m,
    lower_flux_density_t,
    upper_flux_density_t;
    flux_density_t::Real=0.0,
    direction::Integer=1,
)
    field_grid = Float64.(field_strength_a_per_m)
    lower_grid = Float64.(lower_flux_density_t)
    upper_grid = Float64.(upper_flux_density_t)
    field = 0.0
    lower, _ = _independent_piecewise_value_and_slope(field_grid, lower_grid, field)
    upper, _ = _independent_piecewise_value_and_slope(field_grid, upper_grid, field)
    flux_density = Float64(flux_density_t)
    lower <= flux_density <= upper || throw(ArgumentError(
        "independent Tellinen initial state is outside its limiting curves",
    ))
    direction_value = Int(direction)
    direction_value in (-1, 1) || throw(ArgumentError(
        "independent Tellinen direction must be minus or plus one",
    ))
    return IndependentTellinenState(flux_density, field, direction_value, 0)
end

function _independent_tellinen_derivative(
    field_grid,
    lower_grid,
    upper_grid,
    field,
    flux_density,
    direction,
)
    function directional_value_and_slope(values)
        direction >= 0 && return _independent_piecewise_value_and_slope(
            field_grid,
            values,
            field,
        )
        first(field_grid) <= field <= last(field_grid) || throw(DomainError(
            field,
            "independent Tellinen evaluation is outside its domain",
        ))
        index = field == first(field_grid) ? 1 :
            searchsortedfirst(field_grid, field) - 1
        index = clamp(index, 1, length(field_grid) - 1)
        slope = (values[index + 1] - values[index]) /
            (field_grid[index + 1] - field_grid[index])
        return values[index] + slope * (field - field_grid[index]), slope
    end
    lower, lower_slope = directional_value_and_slope(lower_grid)
    upper, upper_slope = directional_value_and_slope(upper_grid)
    vacuum = 4.0e-7 * pi
    if direction > 0
        return vacuum + (lower_slope - vacuum) *
            max((upper - flux_density) / (upper - lower), 1.0e-9)
    end
    return vacuum + (upper_slope - vacuum) *
        max((flux_density - lower) / (upper - lower), 1.0e-9)
end

"""Invert the scalar Tellinen trajectory with an independent RK4 field integrator and bisection."""
function independent_tellinen_trial(
    field_strength_a_per_m,
    lower_flux_density_t,
    upper_flux_density_t,
    accepted::IndependentTellinenState,
    target_flux_density_t::Real;
    maximum_field_increment_a_per_m::Real=0.5,
    flux_tolerance_t::Real=1.0e-10,
)
    field_grid = Float64.(field_strength_a_per_m)
    lower_grid = Float64.(lower_flux_density_t)
    upper_grid = Float64.(upper_flux_density_t)
    target_flux = Float64(target_flux_density_t)
    function integrate(target_field)
        field_delta = target_field - accepted.field_strength_a_per_m
        direction = field_delta == 0.0 ? accepted.direction :
            (field_delta > 0.0 ? 1 : -1)
        step_count = max(
            1,
            ceil(Int, abs(field_delta) / Float64(maximum_field_increment_a_per_m)),
        )
        field_step = field_delta / step_count
        field = accepted.field_strength_a_per_m
        flux = accepted.flux_density_t
        for step in 1:step_count
            derivative_1 = _independent_tellinen_derivative(
                field_grid, lower_grid, upper_grid, field, flux, direction,
            )
            derivative_2 = _independent_tellinen_derivative(
                field_grid, lower_grid, upper_grid,
                field + 0.5 * field_step,
                flux + 0.5 * field_step * derivative_1,
                direction,
            )
            derivative_3 = _independent_tellinen_derivative(
                field_grid, lower_grid, upper_grid,
                field + 0.5 * field_step,
                flux + 0.5 * field_step * derivative_2,
                direction,
            )
            derivative_4 = _independent_tellinen_derivative(
                field_grid, lower_grid, upper_grid,
                field + field_step,
                flux + field_step * derivative_3,
                direction,
            )
            flux += field_step * (
                derivative_1 + 2.0 * derivative_2 +
                2.0 * derivative_3 + derivative_4
            ) / 6.0
            field = step == step_count ? target_field : field + field_step
            lower, _ = _independent_piecewise_value_and_slope(
                field_grid, lower_grid, field,
            )
            upper, _ = _independent_piecewise_value_and_slope(
                field_grid, upper_grid, field,
            )
            flux = clamp(flux, lower, upper)
        end
        return flux, direction
    end
    lower_field = first(field_grid)
    upper_field = last(field_grid)
    for iteration in 1:100
        field = 0.5 * (lower_field + upper_field)
        flux, direction = integrate(field)
        residual = flux - target_flux
        if abs(residual) <= Float64(flux_tolerance_t)
            reversal = direction != accepted.direction
            state = IndependentTellinenState(
                target_flux,
                field,
                direction,
                accepted.reversal_count + Int(reversal),
            )
            derivative = _independent_tellinen_derivative(
                field_grid,
                lower_grid,
                upper_grid,
                field,
                target_flux,
                direction,
            )
            return (
                state,
                differential_reluctivity_m_per_h=inv(derivative),
                residual_t=residual,
                iterations=iteration,
            )
        elseif residual > 0.0
            upper_field = field
        else
            lower_field = field
        end
    end
    throw(ArgumentError("independent Tellinen inverse did not converge"))
end
