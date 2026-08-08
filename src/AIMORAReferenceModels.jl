"""Small analytical and manufactured public reference-model boundary for independent AIMORA checks."""
module AIMORAReferenceModels

using LinearAlgebra

export amplitude_invariant_clarke_matrix,
       synchronous_reference_rotation_matrix,
       phase_to_synchronous_reference,
       synchronous_to_phase_reference,
       two_level_pwm_duties,
       synchronous_current_control_reference,
       series_rl_piecewise_constant_current,
       series_rl_piecewise_constant_trace

"""Return the amplitude-invariant three-phase Clarke matrix whose rows are alpha, beta, and zero axes."""
function amplitude_invariant_clarke_matrix()
    return [
        2.0 / 3.0 -1.0 / 3.0 -1.0 / 3.0
        0.0 sqrt(3.0) / 3.0 -sqrt(3.0) / 3.0
        1.0 / 3.0 1.0 / 3.0 1.0 / 3.0
    ]
end

"""Return the orthogonal alpha-beta rotation that maps a stationary vector into direct-quadrature-zero coordinates."""
function synchronous_reference_rotation_matrix(angle_rad::Real)
    angle = Float64(angle_rad)
    isfinite(angle) || throw(ArgumentError("synchronous-reference angle must be finite"))
    cosine = cos(angle)
    sine = sin(angle)
    return [
        cosine sine 0.0
        -sine cosine 0.0
        0.0 0.0 1.0
    ]
end

function _finite_three_phase_vector(values, name::AbstractString)
    length(values) == 3 || throw(DimensionMismatch("$name must contain three phases"))
    vector = Float64[value for value in values]
    all(isfinite, vector) || throw(ArgumentError("$name must be finite"))
    return vector
end

"""Transform a three-phase vector by independent matrix multiplication into direct-quadrature-zero coordinates."""
function phase_to_synchronous_reference(phase_values, angle_rad::Real)
    phase = _finite_three_phase_vector(phase_values, "phase vector")
    stationary = amplitude_invariant_clarke_matrix() * phase
    return synchronous_reference_rotation_matrix(angle_rad) * stationary
end

"""Invert the independent direct-quadrature-zero matrix transform into phase coordinates."""
function synchronous_to_phase_reference(reference_values, angle_rad::Real)
    synchronous = _finite_three_phase_vector(
        reference_values,
        "synchronous-reference vector",
    )
    stationary = transpose(synchronous_reference_rotation_matrix(angle_rad)) * synchronous
    return amplitude_invariant_clarke_matrix() \ stationary
end

"""Compute ideal two-level sinusoidal or minimum-maximum zero-sequence-injected PWM duties; the latter is centered-space-vector-equivalent in line voltage within the linear region."""
function two_level_pwm_duties(
    phase_voltage_reference_v,
    dc_link_voltage_v::Real;
    modulation::Symbol = :zero_sequence_injected,
    minimum_duty::Real = 0.0,
    maximum_duty::Real = 1.0,
)
    reference = _finite_three_phase_vector(
        phase_voltage_reference_v,
        "phase-voltage reference",
    )
    dc_voltage = Float64(dc_link_voltage_v)
    isfinite(dc_voltage) && dc_voltage > 0.0 || throw(ArgumentError(
        "DC-link voltage must be finite and positive",
    ))
    lower = Float64(minimum_duty)
    upper = Float64(maximum_duty)
    0.0 <= lower < upper <= 1.0 || throw(ArgumentError(
        "PWM duty bounds must satisfy 0 <= minimum < maximum <= 1",
    ))
    common_mode = if modulation === :sinusoidal
        0.0
    elseif modulation in (:zero_sequence_injected, :centered_space_vector_equivalent)
        -0.5 * (maximum(reference) + minimum(reference))
    else
        throw(ArgumentError(
            "modulation must be :sinusoidal, :zero_sequence_injected, or :centered_space_vector_equivalent",
        ))
    end
    return clamp.(0.5 .+ (reference .+ common_mode) ./ dc_voltage, lower, upper)
end

"""Evaluate one independent matrix-form synchronous current-controller sample for a balanced three-phase grid-following converter."""
function synchronous_current_control_reference(
    phase_voltage_v,
    phase_current_a,
    angle_rad::Real,
    dc_link_voltage_v::Real;
    grid_line_line_rms_v::Real,
    active_power_reference_w::Real,
    reactive_power_reference_var::Real,
    current_limit_a::Real,
    control_period_s::Real,
    series_resistance_ohm::Real,
    series_inductance_h::Real,
    frequency_hz::Real,
    proportional_gain_v_per_a::Real,
    integral_gain_v_per_as::Real,
    direct_integral_as::Real = 0.0,
    quadrature_integral_as::Real = 0.0,
    modulation::Symbol = :zero_sequence_injected,
    minimum_duty::Real = 0.0,
    maximum_duty::Real = 1.0,
)
    voltage = phase_to_synchronous_reference(phase_voltage_v, angle_rad)
    current = phase_to_synchronous_reference(phase_current_a, angle_rad)
    inputs = Float64.((
        dc_link_voltage_v,
        grid_line_line_rms_v,
        active_power_reference_w,
        reactive_power_reference_var,
        current_limit_a,
        control_period_s,
        series_resistance_ohm,
        series_inductance_h,
        frequency_hz,
        proportional_gain_v_per_a,
        integral_gain_v_per_as,
        direct_integral_as,
        quadrature_integral_as,
    ))
    all(isfinite, inputs) || throw(ArgumentError(
        "synchronous current-controller reference inputs must be finite",
    ))
    dc_voltage, grid_voltage, active_reference, reactive_reference,
        current_limit, control_period, resistance, inductance, frequency,
        proportional_gain, integral_gain, direct_integral,
        quadrature_integral = inputs
    dc_voltage > 0.0 || throw(ArgumentError("DC-link voltage must be positive"))
    grid_voltage > 0.0 || throw(ArgumentError("grid voltage must be positive"))
    current_limit > 0.0 || throw(ArgumentError("current limit must be positive"))
    control_period > 0.0 || throw(ArgumentError("control period must be positive"))
    resistance >= 0.0 || throw(ArgumentError("series resistance must be nonnegative"))
    inductance > 0.0 || throw(ArgumentError("series inductance must be positive"))
    frequency > 0.0 || throw(ArgumentError("frequency must be positive"))
    proportional_gain >= 0.0 || throw(ArgumentError("proportional gain must be nonnegative"))
    integral_gain >= 0.0 || throw(ArgumentError("integral gain must be nonnegative"))

    direct_voltage = max(abs(voltage[1]), 0.05 * grid_voltage)
    current_reference = [
        (2.0 / 3.0) * active_reference / direct_voltage,
        -(2.0 / 3.0) * reactive_reference / direct_voltage,
    ]
    reference_magnitude = hypot(current_reference...)
    if reference_magnitude > current_limit
        current_reference .*= current_limit / reference_magnitude
    end
    current_error = current_reference .- current[1:2]
    integral_candidate = [direct_integral, quadrature_integral] .+
        control_period .* current_error
    omega = 2.0 * pi * frequency
    impedance_feedforward = [
        resistance * current[1] - omega * inductance * current[2],
        resistance * current[2] + omega * inductance * current[1],
    ]
    voltage_reference = voltage[1:2] .+ impedance_feedforward .+
        proportional_gain .* current_error .+ integral_gain .* integral_candidate
    voltage_limit = 0.95 * dc_voltage / sqrt(3.0)
    reference_voltage_magnitude = hypot(voltage_reference...)
    saturated = reference_voltage_magnitude > voltage_limit
    if saturated && reference_voltage_magnitude > 0.0
        voltage_reference .*= voltage_limit / reference_voltage_magnitude
    end
    accepted_integral = saturated ? [direct_integral, quadrature_integral] : integral_candidate
    phase_reference = synchronous_to_phase_reference(
        (voltage_reference[1], voltage_reference[2], 0.0),
        angle_rad,
    )
    duties = two_level_pwm_duties(
        phase_reference,
        dc_voltage;
        modulation,
        minimum_duty,
        maximum_duty,
    )
    return (
        duties,
        phase_voltage_reference_v = phase_reference,
        direct_current_reference_a = current_reference[1],
        quadrature_current_reference_a = current_reference[2],
        direct_current_a = current[1],
        quadrature_current_a = current[2],
        direct_integral_as = accepted_integral[1],
        quadrature_integral_as = accepted_integral[2],
        saturated,
    )
end

"""Advance an R-L current exactly for one interval with constant applied branch voltage."""
function series_rl_piecewise_constant_current(
    initial_current_a::Real,
    branch_voltage_v::Real,
    resistance_ohm::Real,
    inductance_h::Real,
    interval_s::Real,
)
    current = Float64(initial_current_a)
    voltage = Float64(branch_voltage_v)
    resistance = Float64(resistance_ohm)
    inductance = Float64(inductance_h)
    interval = Float64(interval_s)
    all(isfinite, (current, voltage, resistance, inductance, interval)) ||
        throw(ArgumentError("series R-L reconstruction inputs must be finite"))
    resistance >= 0.0 || throw(ArgumentError("series resistance must be nonnegative"))
    inductance > 0.0 || throw(ArgumentError("series inductance must be positive"))
    interval >= 0.0 || throw(ArgumentError("series R-L interval must be nonnegative"))
    if resistance == 0.0
        return current + interval * voltage / inductance
    end
    decay = exp(-resistance * interval / inductance)
    steady_current = voltage / resistance
    return steady_current + (current - steady_current) * decay
end

"""Reconstruct an R-L current trace from independently supplied piecewise-constant interval voltages."""
function series_rl_piecewise_constant_trace(
    initial_current_a::Real,
    interval_voltage_v,
    resistance_ohm::Real,
    inductance_h::Real,
    interval_s::Real,
)
    voltages = Float64.(interval_voltage_v)
    all(isfinite, voltages) || throw(ArgumentError(
        "series R-L interval voltages must be finite",
    ))
    trace = Vector{Float64}(undef, length(voltages) + 1)
    trace[1] = Float64(initial_current_a)
    for interval_index in eachindex(voltages)
        trace[interval_index + 1] = series_rl_piecewise_constant_current(
            trace[interval_index],
            voltages[interval_index],
            resistance_ohm,
            inductance_h,
            interval_s,
        )
    end
    return trace
end

end
