"""Independent generic semiconductor state used only by public reference calculations."""
struct IndependentSemiconductorState
    stored_recovery_charge_c::Float64
    junction_voltage_v::Float64
    turn_off_tail_current_a::Float64
    thermal_temperature_k::Vector{Float64}
end

function independent_recovered_charge_backward_euler(
    previous_charge_c::Real,
    diode_current_a::Real,
    lifetime_s::Real,
    step_s::Real,
)
    previous_charge, current, lifetime, step = Float64.((
        previous_charge_c,
        diode_current_a,
        lifetime_s,
        step_s,
    ))
    all(isfinite, (previous_charge, current, lifetime, step)) || throw(ArgumentError(
        "independent recovered-charge inputs must be finite",
    ))
    previous_charge >= 0.0 || throw(ArgumentError(
        "independent recovered charge must be nonnegative",
    ))
    lifetime > 0.0 && step > 0.0 || throw(ArgumentError(
        "independent recovery lifetime and timestep must be positive",
    ))
    accepted_charge = max(
        0.0,
        (previous_charge + step * current) / (1.0 + step / lifetime),
    )
    recovered_charge = max(0.0, previous_charge - accepted_charge)
    return (
        accepted_charge_c=accepted_charge,
        recovered_charge_c=recovered_charge,
        recovery_current_a=current < 0.0 ? current : 0.0,
        balance_residual_a=(accepted_charge - previous_charge) / step -
            current + accepted_charge / lifetime,
    )
end

function independent_junction_capacitance(
    zero_bias_capacitance_f::Real,
    junction_voltage_v::Real,
    grading_exponent::Real,
    terminal_voltage_v::Real,
)
    capacitance, junction_voltage, exponent, voltage = Float64.((
        zero_bias_capacitance_f,
        junction_voltage_v,
        grading_exponent,
        terminal_voltage_v,
    ))
    capacitance > 0.0 && junction_voltage > 0.0 && 0.0 <= exponent < 1.0 ||
        throw(ArgumentError("independent junction parameters are outside their physical domain"))
    return voltage >= 0.0 ? capacitance :
        capacitance * (1.0 - voltage / junction_voltage)^(-exponent)
end

function independent_junction_charge(
    zero_bias_capacitance_f::Real,
    junction_voltage_v::Real,
    grading_exponent::Real,
    terminal_voltage_v::Real,
)
    capacitance, junction_voltage, exponent, voltage = Float64.((
        zero_bias_capacitance_f,
        junction_voltage_v,
        grading_exponent,
        terminal_voltage_v,
    ))
    independent_junction_capacitance(capacitance, junction_voltage, exponent, voltage)
    voltage >= 0.0 && return capacitance * voltage
    normalized_voltage = 1.0 - voltage / junction_voltage
    return -capacitance * junction_voltage *
        (normalized_voltage^(1.0 - exponent) - 1.0) / (1.0 - exponent)
end

function independent_junction_energy(
    zero_bias_capacitance_f::Real,
    junction_voltage_v::Real,
    grading_exponent::Real,
    terminal_voltage_v::Real,
)
    capacitance, junction_voltage, exponent, voltage = Float64.((
        zero_bias_capacitance_f,
        junction_voltage_v,
        grading_exponent,
        terminal_voltage_v,
    ))
    independent_junction_capacitance(capacitance, junction_voltage, exponent, voltage)
    voltage >= 0.0 && return 0.5 * capacitance * voltage^2
    normalized_voltage = 1.0 - voltage / junction_voltage
    return capacitance * junction_voltage^2 * (
        (normalized_voltage^(2.0 - exponent) - 1.0) / (2.0 - exponent) -
        (normalized_voltage^(1.0 - exponent) - 1.0) / (1.0 - exponent)
    )
end

function independent_turn_off_tail(
    initial_current_a::Real,
    decay_time_s::Real,
    elapsed_time_s::Real;
    cutoff_current_a::Real=0.0,
)
    initial_current, decay_time, elapsed_time, cutoff = Float64.((
        initial_current_a,
        decay_time_s,
        elapsed_time_s,
        cutoff_current_a,
    ))
    initial_current >= 0.0 && decay_time > 0.0 && elapsed_time >= 0.0 && cutoff >= 0.0 ||
        throw(ArgumentError("independent tail inputs are outside their physical domain"))
    current = initial_current * exp(-elapsed_time / decay_time)
    return current > cutoff ? current : 0.0
end

function _independent_axis_cell(axis::AbstractVector{<:Real}, coordinate::Float64)
    values = Float64.(axis)
    all(diff(values) .> 0.0) || throw(ArgumentError(
        "independent interpolation axis must be strictly increasing",
    ))
    first(values) <= coordinate <= last(values) || throw(DomainError(
        coordinate,
        "independent interpolation coordinate lies outside its table domain",
    ))
    coordinate == last(values) && return length(values) - 1, 1.0, values
    lower_index = clamp(searchsortedlast(values, coordinate), 1, length(values) - 1)
    fraction = (coordinate - values[lower_index]) /
        (values[lower_index + 1] - values[lower_index])
    return lower_index, fraction, values
end

function independent_trilinear_semiconductor_energy(
    values_j::AbstractArray{<:Real,3},
    current_axis_a::AbstractVector{<:Real},
    voltage_axis_v::AbstractVector{<:Real},
    temperature_axis_k::AbstractVector{<:Real},
    current_a::Real,
    voltage_v::Real,
    temperature_k::Real,
)
    current_index, current_fraction, current_axis =
        _independent_axis_cell(current_axis_a, Float64(current_a))
    voltage_index, voltage_fraction, voltage_axis =
        _independent_axis_cell(voltage_axis_v, Float64(voltage_v))
    temperature_index, temperature_fraction, temperature_axis =
        _independent_axis_cell(temperature_axis_k, Float64(temperature_k))
    size(values_j) == (
        length(current_axis),
        length(voltage_axis),
        length(temperature_axis),
    ) || throw(DimensionMismatch("independent energy table does not match its axes"))
    energy = 0.0
    for current_offset in 0:1, voltage_offset in 0:1, temperature_offset in 0:1
        current_weight = current_offset == 0 ?
            1.0 - current_fraction : current_fraction
        voltage_weight = voltage_offset == 0 ?
            1.0 - voltage_fraction : voltage_fraction
        temperature_weight = temperature_offset == 0 ?
            1.0 - temperature_fraction : temperature_fraction
        energy += current_weight * voltage_weight * temperature_weight * values_j[
            current_index + current_offset,
            voltage_index + voltage_offset,
            temperature_index + temperature_offset,
        ]
    end
    return energy
end

function independent_cauer_backward_euler(
    capacitance_j_per_k::AbstractVector{<:Real},
    resistance_k_per_w::AbstractVector{<:Real},
    previous_temperature_k::AbstractVector{<:Real},
    ambient_temperature_k::Real,
    loss_power_w::Real,
    step_s::Real,
)
    capacitance = Float64.(capacitance_j_per_k)
    resistance = Float64.(resistance_k_per_w)
    previous_temperature = Float64.(previous_temperature_k)
    ambient, loss_power, step = Float64.((ambient_temperature_k, loss_power_w, step_s))
    stage_count = length(capacitance)
    stage_count > 0 && length(resistance) == stage_count &&
        length(previous_temperature) == stage_count || throw(DimensionMismatch(
            "independent Cauer state arrays must have equal nonzero length",
        ))
    all(>(0.0), capacitance) && all(>(0.0), resistance) &&
        loss_power >= 0.0 && step > 0.0 || throw(ArgumentError(
            "independent Cauer parameters must be passive and the timestep positive",
        ))
    conductance = zeros(Float64, stage_count, stage_count)
    source = zeros(Float64, stage_count)
    previous_rise = previous_temperature .- ambient
    for stage in 1:stage_count
        storage = capacitance[stage] / step
        conductance[stage, stage] += storage
        source[stage] += storage * previous_rise[stage]
        stage == 1 && (source[stage] += loss_power)
        if stage > 1
            coupling = inv(resistance[stage - 1])
            conductance[stage, stage] += coupling
            conductance[stage, stage - 1] -= coupling
        end
        if stage < stage_count
            coupling = inv(resistance[stage])
            conductance[stage, stage] += coupling
            conductance[stage, stage + 1] -= coupling
        else
            conductance[stage, stage] += inv(resistance[stage])
        end
    end
    temperature_rise = conductance \ source
    temperature = temperature_rise .+ ambient
    ambient_heat_flow = temperature_rise[end] / resistance[end]
    stored_energy = sum(capacitance .* temperature_rise)
    return (
        temperature_k=temperature,
        ambient_heat_flow_w=ambient_heat_flow,
        stored_energy_j=stored_energy,
    )
end
