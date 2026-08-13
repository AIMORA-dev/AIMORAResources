function independent_vsc_current_projection(
    direct_a::Real,
    quadrature_a::Real,
    limit_a::Real,
    priority::Symbol,
)
    direct, quadrature, limit = Float64.((direct_a, quadrature_a, limit_a))
    all(isfinite, (direct, quadrature, limit)) && limit > 0.0 ||
        throw(ArgumentError("VSC current projection inputs must be finite and positive"))
    priority in (:active, :reactive, :magnitude) ||
        throw(ArgumentError("VSC current priority is unsupported"))
    hypot(direct, quadrature) <= limit &&
        return (direct=direct, quadrature=quadrature, limited=false)
    if priority === :active
        direct = clamp(direct, -limit, limit)
        remaining = sqrt(max(0.0, limit^2 - direct^2))
        quadrature = clamp(quadrature, -remaining, remaining)
    elseif priority === :reactive
        quadrature = clamp(quadrature, -limit, limit)
        remaining = sqrt(max(0.0, limit^2 - quadrature^2))
        direct = clamp(direct, -remaining, remaining)
    else
        scale = limit / hypot(direct, quadrature)
        direct *= scale
        quadrature *= scale
    end
    return (direct=direct, quadrature=quadrature, limited=true)
end

function independent_vsc_power_current_reference(
    active_power_w::Real,
    reactive_power_var::Real,
    direct_voltage_v::Real,
    quadrature_voltage_v::Real,
    current_limit_a::Real,
    priority::Symbol,
)
    active, reactive, direct_voltage, quadrature_voltage = Float64.((
        active_power_w,
        reactive_power_var,
        direct_voltage_v,
        quadrature_voltage_v,
    ))
    all(isfinite, (active, reactive, direct_voltage, quadrature_voltage)) ||
        throw(ArgumentError("VSC power-current inputs must be finite"))
    voltage_squared = max(direct_voltage^2 + quadrature_voltage^2, 1.0)
    direct = (2.0 / 3.0) *
        (direct_voltage * active + quadrature_voltage * reactive) / voltage_squared
    quadrature = (2.0 / 3.0) *
        (quadrature_voltage * active - direct_voltage * reactive) / voltage_squared
    return independent_vsc_current_projection(
        direct,
        quadrature,
        current_limit_a,
        priority,
    )
end

function independent_vsc_pll_sample(
    angle_rad::Real,
    integral_rad_per_s::Real,
    direct_voltage_v::Real,
    quadrature_voltage_v::Real,
    nominal_frequency_hz::Real,
    proportional_gain_rad_per_s::Real,
    integral_gain_rad_per_s2::Real,
    voltage_floor_v::Real,
    minimum_frequency_hz::Real,
    maximum_frequency_hz::Real,
    step_s::Real,
)
    angle, integral, direct, quadrature, nominal, proportional_gain, integral_gain,
        floor_voltage, minimum_frequency, maximum_frequency, step = Float64.((
            angle_rad,
            integral_rad_per_s,
            direct_voltage_v,
            quadrature_voltage_v,
            nominal_frequency_hz,
            proportional_gain_rad_per_s,
            integral_gain_rad_per_s2,
            voltage_floor_v,
            minimum_frequency_hz,
            maximum_frequency_hz,
            step_s,
        ))
    all(isfinite, (angle, integral, direct, quadrature, nominal, proportional_gain,
        integral_gain, floor_voltage, minimum_frequency, maximum_frequency, step)) ||
        throw(ArgumentError("VSC PLL inputs must be finite"))
    magnitude = hypot(direct, quadrature)
    magnitude >= floor_voltage || return (
        angle_rad=angle,
        integral_rad_per_s=integral,
        frequency_rad_per_s=2.0 * pi * nominal,
        error=0.0,
        locked=false,
    )
    error = quadrature / max(magnitude, floor_voltage)
    integral += step * integral_gain * error
    frequency = clamp(
        2.0 * pi * nominal + proportional_gain * error + integral,
        2.0 * pi * minimum_frequency,
        2.0 * pi * maximum_frequency,
    )
    return (
        angle_rad=rem2pi(angle + step * frequency, RoundNearest),
        integral_rad_per_s=integral,
        frequency_rad_per_s=frequency,
        error=error,
        locked=abs(error) <= 0.05,
    )
end

function independent_vsc_resonator_sample(
    derivative_state::Real,
    integral_state::Real,
    error_a::Real,
    frequency_rad_per_s::Real,
    harmonic_order::Integer,
    gain_v_per_a::Real,
    bandwidth_rad_per_s::Real,
    step_s::Real,
)
    x1, x2, error, frequency, gain, bandwidth, step = Float64.((
        derivative_state,
        integral_state,
        error_a,
        frequency_rad_per_s,
        gain_v_per_a,
        bandwidth_rad_per_s,
        step_s,
    ))
    order = Int(harmonic_order)
    all(isfinite, (x1, x2, error, frequency, gain, bandwidth, step)) &&
        order > 0 && bandwidth > 0.0 && step > 0.0 ||
        throw(ArgumentError("VSC resonator inputs are outside their domain"))
    derivative(a, b) = (
        -2.0 * bandwidth * a - (order * frequency)^2 * b +
        2.0 * gain * bandwidth * error,
        a,
    )
    k1 = derivative(x1, x2)
    k2 = derivative(x1 + 0.5 * step * k1[1], x2 + 0.5 * step * k1[2])
    k3 = derivative(x1 + 0.5 * step * k2[1], x2 + 0.5 * step * k2[2])
    k4 = derivative(x1 + step * k3[1], x2 + step * k3[2])
    return (
        derivative_state=x1 + step * (k1[1] + 2k2[1] + 2k3[1] + k4[1]) / 6.0,
        integral_state=x2 + step * (k1[2] + 2k2[2] + 2k3[2] + k4[2]) / 6.0,
    )
end

function independent_vsc_power_filter_sample(
    previous::Real,
    measured::Real,
    time_constant_s::Real,
    step_s::Real,
)
    state, input, time_constant, step = Float64.((
        previous,
        measured,
        time_constant_s,
        step_s,
    ))
    all(isfinite, (state, input, time_constant, step)) &&
        time_constant > 0.0 && step > 0.0 ||
        throw(ArgumentError("VSC power-filter inputs are outside their domain"))
    decay = exp(-step / time_constant)
    return decay * state + (1.0 - decay) * input
end

function independent_vsc_droop_sample(
    angle_rad::Real,
    filtered_active_power_w::Real,
    active_power_reference_w::Real,
    nominal_frequency_hz::Real,
    droop_rad_per_ws::Real,
    step_s::Real,
)
    angle, measured, reference, nominal, droop, step = Float64.((
        angle_rad,
        filtered_active_power_w,
        active_power_reference_w,
        nominal_frequency_hz,
        droop_rad_per_ws,
        step_s,
    ))
    frequency = 2.0 * pi * nominal - droop * (measured - reference)
    return (angle_rad=rem2pi(angle + step * frequency, RoundNearest),
        frequency_rad_per_s=frequency)
end

function independent_vsc_swing_sample(
    angle_rad::Real,
    frequency_rad_per_s::Real,
    filtered_active_power_w::Real,
    active_power_reference_w::Real,
    nominal_frequency_hz::Real,
    inertia_w_s2_per_rad::Real,
    damping_w_s_per_rad::Real,
    step_s::Real,
)
    angle, frequency, measured, reference, nominal, inertia, damping, step = Float64.((
        angle_rad,
        frequency_rad_per_s,
        filtered_active_power_w,
        active_power_reference_w,
        nominal_frequency_hz,
        inertia_w_s2_per_rad,
        damping_w_s_per_rad,
        step_s,
    ))
    inertia > 0.0 && damping >= 0.0 && step > 0.0 ||
        throw(ArgumentError("VSC swing inputs are outside their domain"))
    acceleration = (reference - measured - damping *
        (frequency - 2.0 * pi * nominal)) / inertia
    frequency += step * acceleration
    return (angle_rad=rem2pi(angle + step * frequency, RoundNearest),
        frequency_rad_per_s=frequency, acceleration_rad_per_s2=acceleration)
end

function independent_vsc_instantaneous_power(phase_voltage_v, phase_current_a)
    voltage = _finite_three_phase_vector(phase_voltage_v, "VSC phase voltage")
    current = _finite_three_phase_vector(phase_current_a, "VSC phase current")
    stationary_voltage = amplitude_invariant_clarke_matrix() * voltage
    stationary_current = amplitude_invariant_clarke_matrix() * current
    return (
        active_w=1.5 * (stationary_voltage[1] * stationary_current[1] +
            stationary_voltage[2] * stationary_current[2]) +
            3.0 * stationary_voltage[3] * stationary_current[3],
        reactive_var=1.5 * (stationary_voltage[2] * stationary_current[1] -
            stationary_voltage[1] * stationary_current[2]),
    )
end

function independent_vsc_sequence_components(phase_samples::AbstractMatrix{<:Real}, angles_rad)
    size(phase_samples, 1) == 3 ||
        throw(DimensionMismatch("VSC sequence samples require three phase rows"))
    size(phase_samples, 2) == length(angles_rad) ||
        throw(DimensionMismatch("VSC sequence sample and angle counts must match"))
    positive = 0.0 + 0.0im
    negative = 0.0 + 0.0im
    zero = 0.0 + 0.0im
    for sample in axes(phase_samples, 2)
        stationary = amplitude_invariant_clarke_matrix() * Float64.(phase_samples[:, sample])
        angle = Float64(angles_rad[sample])
        stationary_complex = stationary[1] + im * stationary[2]
        positive += stationary_complex * cis(-angle)
        negative += stationary_complex * cis(angle)
        zero += 2.0 * stationary[3] * cis(-angle)
    end
    count = size(phase_samples, 2)
    return (positive=positive / count, negative=negative / count, zero=zero / count)
end

function independent_vsc_capacitor_companion_residual(
    previous_voltage_v::Real,
    previous_current_a::Real,
    voltage_v::Real,
    current_a::Real,
    capacitance_f::Real,
    step_s::Real,
)
    previous_voltage, previous_current, voltage, current, capacitance, step = Float64.((
        previous_voltage_v,
        previous_current_a,
        voltage_v,
        current_a,
        capacitance_f,
        step_s,
    ))
    capacitance > 0.0 && step > 0.0 ||
        throw(ArgumentError("VSC capacitor inputs are outside their domain"))
    work = 0.5 * step * (previous_voltage * previous_current + voltage * current)
    stored_change = 0.5 * capacitance * (voltage^2 - previous_voltage^2)
    return work - stored_change
end
