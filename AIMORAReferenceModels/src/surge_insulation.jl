function _independent_surge_finite(value::Real, label::AbstractString)
    converted = Float64(value)
    isfinite(converted) || throw(ArgumentError("independent $label must be finite"))
    return converted
end

function _independent_surge_positive(value::Real, label::AbstractString)
    converted = _independent_surge_finite(value, label)
    converted > 0.0 || throw(ArgumentError("independent $label must be positive"))
    return converted
end

"""Evaluate and peak-normalize a difference-of-exponentials lightning current without production waveform code."""
function independent_double_exponential_lightning(
    time_s::Real,
    peak_current_a::Real,
    slow_decay_rate_per_s::Real,
    fast_decay_rate_per_s::Real,
)
    time = _independent_surge_finite(time_s, "lightning time")
    peak = _independent_surge_finite(peak_current_a, "lightning peak")
    slow = _independent_surge_positive(slow_decay_rate_per_s, "slow lightning rate")
    fast = _independent_surge_positive(fast_decay_rate_per_s, "fast lightning rate")
    peak != 0.0 || throw(ArgumentError("independent lightning peak must be nonzero"))
    fast > slow || throw(ArgumentError("independent fast lightning rate must exceed slow rate"))
    peak_time = log(fast / slow) / (fast - slow)
    normalization = exp(-slow * peak_time) - exp(-fast * peak_time)
    current = time < 0.0 ? 0.0 : peak * (exp(-slow * time) - exp(-fast * time)) / normalization
    return (current_a=current, peak_time_s=peak_time, normalization=normalization)
end

"""Return exact infinite-horizon charge and specific-energy integrals for a double exponential."""
function independent_double_exponential_integrals(
    peak_current_a::Real,
    slow_decay_rate_per_s::Real,
    fast_decay_rate_per_s::Real,
)
    waveform = independent_double_exponential_lightning(
        0.0,
        peak_current_a,
        slow_decay_rate_per_s,
        fast_decay_rate_per_s,
    )
    peak = Float64(peak_current_a)
    slow = Float64(slow_decay_rate_per_s)
    fast = Float64(fast_decay_rate_per_s)
    scale = peak / waveform.normalization
    return (
        charge_c=scale * (inv(slow) - inv(fast)),
        specific_energy_a2s=scale^2 * (
            inv(2.0 * slow) - 2.0 / (slow + fast) + inv(2.0 * fast)
        ),
    )
end

"""Evaluate a Heidler impulse whose peak follows from a monotone scalar stationarity equation."""
function independent_heidler_lightning(
    time_s::Real,
    peak_current_a::Real,
    front_time_s::Real,
    tail_time_s::Real,
    exponent::Real,
)
    time = _independent_surge_finite(time_s, "Heidler time")
    peak = _independent_surge_finite(peak_current_a, "Heidler peak")
    front = _independent_surge_positive(front_time_s, "Heidler front time")
    tail = _independent_surge_positive(tail_time_s, "Heidler tail time")
    order = _independent_surge_positive(exponent, "Heidler exponent")
    peak != 0.0 || throw(ArgumentError("independent Heidler peak must be nonzero"))
    tail > front || throw(ArgumentError("independent Heidler tail must exceed front"))
    lower = 0.0
    upper = order * tail
    for _ in 1:180
        middle = 0.5 * (lower + upper)
        stationarity = middle * (1.0 + (middle / front)^order) - order * tail
        if stationarity < 0.0
            lower = middle
        else
            upper = middle
        end
    end
    peak_time = 0.5 * (lower + upper)
    raw(t) = begin
        ratio_power = (t / front)^order
        ratio_power / (1.0 + ratio_power) * exp(-t / tail)
    end
    normalization = raw(peak_time)
    current = time < 0.0 ? 0.0 : peak * raw(time) / normalization
    return (current_a=current, peak_time_s=peak_time, normalization=normalization)
end

"""Advance the independently derived exponential combined Cassie-Mayr conductance balance."""
function independent_combined_arc_step(
    conductance_s::Real,
    voltage_v::Real,
    step_s::Real;
    cassie_power_w::Real,
    mayr_power_w::Real,
    cassie_time_constant_s::Real,
    mayr_time_constant_s::Real,
    transition_power_w::Real,
    minimum_conductance_s::Real,
    maximum_conductance_s::Real,
)
    conductance = _independent_surge_positive(conductance_s, "arc conductance")
    voltage = _independent_surge_finite(voltage_v, "arc voltage")
    step = _independent_surge_positive(step_s, "arc step")
    cassie_power = _independent_surge_positive(cassie_power_w, "Cassie power")
    mayr_power = _independent_surge_positive(mayr_power_w, "Mayr power")
    cassie_time = _independent_surge_positive(cassie_time_constant_s, "Cassie time")
    mayr_time = _independent_surge_positive(mayr_time_constant_s, "Mayr time")
    transition = _independent_surge_positive(transition_power_w, "arc transition power")
    lower = _independent_surge_positive(minimum_conductance_s, "minimum arc conductance")
    upper = _independent_surge_positive(maximum_conductance_s, "maximum arc conductance")
    lower <= conductance <= upper || throw(ArgumentError("independent arc state is outside bounds"))
    power = conductance * voltage^2
    blend = power / (power + transition)
    cassie_rate = (power / cassie_power - 1.0) / cassie_time
    mayr_rate = (power / mayr_power - 1.0) / mayr_time
    next_conductance = clamp(
        conductance * exp(clamp(step * (blend * cassie_rate + (1.0 - blend) * mayr_rate), -80.0, 80.0)),
        lower,
        upper,
    )
    return (conductance_s=next_conductance, current_a=next_conductance * voltage)
end

"""Advance an independent Mayr-family fault-arc conductance balance."""
function independent_fault_arc_step(
    conductance_s::Real,
    voltage_v::Real,
    step_s::Real;
    cooling_power_w::Real,
    time_constant_s::Real,
    minimum_conductance_s::Real,
    maximum_conductance_s::Real,
)
    conductance = _independent_surge_positive(conductance_s, "fault-arc conductance")
    voltage = _independent_surge_finite(voltage_v, "fault-arc voltage")
    step = _independent_surge_positive(step_s, "fault-arc step")
    cooling = _independent_surge_positive(cooling_power_w, "fault-arc cooling power")
    time_constant = _independent_surge_positive(time_constant_s, "fault-arc time constant")
    lower = _independent_surge_positive(minimum_conductance_s, "minimum fault-arc conductance")
    upper = _independent_surge_positive(maximum_conductance_s, "maximum fault-arc conductance")
    rate = (conductance * voltage^2 / cooling - 1.0) / time_constant
    next_conductance = clamp(conductance * exp(clamp(step * rate, -80.0, 80.0)), lower, upper)
    return (conductance_s=next_conductance, current_a=next_conductance * voltage)
end

"""Evaluate vacuum chop and restrike indicators from an explicit contact state."""
function independent_vacuum_surfaces(
    state::Symbol,
    current_a::Real,
    recovery_voltage_v::Real,
    time_s::Real;
    separation_time_s::Real,
    chopping_current_a::Real,
    initial_dielectric_strength_v::Real,
    dielectric_recovery_rate_v_per_s::Real,
    maximum_dielectric_strength_v::Real,
)
    time = _independent_surge_finite(time_s, "vacuum time")
    separation = _independent_surge_finite(separation_time_s, "vacuum separation time")
    elapsed = max(time - separation, 0.0)
    strength = min(
        Float64(initial_dielectric_strength_v) + Float64(dielectric_recovery_rate_v_per_s) * elapsed,
        Float64(maximum_dielectric_strength_v),
    )
    return (
        chop_surface_a=state === :separating ? abs(Float64(current_a)) - Float64(chopping_current_a) : Inf,
        restrike_surface_v=state === :open ? abs(Float64(recovery_voltage_v)) - strength : -Inf,
        dielectric_strength_v=strength,
    )
end

"""Evaluate a symmetric log-log interpolated metal-oxide characteristic directly from its knots."""
function independent_metal_oxide_characteristic(
    current_knots_a::AbstractVector{<:Real},
    voltage_knots_v::AbstractVector{<:Real},
    voltage_v::Real;
    extrapolate::Bool=false,
)
    currents = Float64.(current_knots_a)
    voltages = Float64.(voltage_knots_v)
    length(currents) == length(voltages) >= 2 || throw(DimensionMismatch("independent metal-oxide knots differ"))
    magnitude = abs(_independent_surge_finite(voltage_v, "metal-oxide voltage"))
    iszero(magnitude) && return (current_a=0.0, derivative_s=0.0, segment=0)
    if !extrapolate && !(first(voltages) <= magnitude <= last(voltages))
        throw(DomainError(magnitude, "independent metal-oxide voltage is outside its knots"))
    end
    segment = clamp(searchsortedlast(voltages, magnitude), 1, length(voltages) - 1)
    exponent = log(currents[segment + 1] / currents[segment]) /
        log(voltages[segment + 1] / voltages[segment])
    coefficient = currents[segment] / voltages[segment]^exponent
    current_magnitude = coefficient * magnitude^exponent
    return (
        current_a=copysign(current_magnitude, Float64(voltage_v)),
        derivative_s=exponent * coefficient * magnitude^(exponent - 1.0),
        segment=segment,
    )
end

"""Integrate charge, absorbed energy, and a lumped arrester temperature by trapezoidal power."""
function independent_arrester_duty_step(
    previous_voltage_v::Real,
    previous_current_a::Real,
    voltage_v::Real,
    current_a::Real,
    elapsed_s::Real;
    temperature_k::Real,
    ambient_temperature_k::Real,
    thermal_capacitance_j_per_k::Real,
    thermal_resistance_k_per_w::Real=Inf,
)
    elapsed = _independent_surge_positive(elapsed_s, "arrester elapsed time")
    average_current = 0.5 * (Float64(previous_current_a) + Float64(current_a))
    average_power = 0.5 * max(
        Float64(previous_voltage_v) * Float64(previous_current_a) + Float64(voltage_v) * Float64(current_a),
        0.0,
    )
    resistance = Float64(thermal_resistance_k_per_w)
    cooling = isinf(resistance) ? 0.0 : (Float64(temperature_k) - Float64(ambient_temperature_k)) / resistance
    next_temperature = max(
        Float64(ambient_temperature_k),
        Float64(temperature_k) + elapsed * (average_power - cooling) / Float64(thermal_capacitance_j_per_k),
    )
    return (
        charge_increment_c=elapsed * average_current,
        energy_increment_j=elapsed * average_power,
        temperature_k=next_temperature,
    )
end

"""Evaluate the positive-real grounding admittance by direct complex arithmetic."""
function independent_positive_real_grounding(
    frequency_hz::Real,
    direct_conductance_s::Real,
    pole_rates_per_s::AbstractVector{<:Real},
    residue_conductances_s::AbstractVector{<:Real},
)
    poles = Float64.(pole_rates_per_s)
    residues = Float64.(residue_conductances_s)
    length(poles) == length(residues) || throw(DimensionMismatch("independent grounding terms differ"))
    frequency = _independent_surge_finite(frequency_hz, "grounding frequency")
    frequency >= 0.0 || throw(ArgumentError("independent grounding frequency must be nonnegative"))
    frequency_variable = complex(0.0, 2.0 * pi * frequency)
    admittance = complex(Float64(direct_conductance_s), 0.0)
    for index in eachindex(poles)
        admittance += residues[index] * frequency_variable / (frequency_variable + poles[index])
    end
    return (admittance_s=admittance, impedance_ohm=inv(admittance))
end

"""Advance a compact effective-radius soil-ionization state independently."""
function independent_ionizing_ground_step(
    radius_m::Real,
    voltage_v::Real,
    step_s::Real;
    linear_resistance_ohm::Real,
    electrode_radius_m::Real,
    maximum_ionized_radius_m::Real,
    critical_field_v_per_m::Real,
    expansion_rate_m_per_v_s::Real,
    recovery_rate_per_s::Real,
)
    radius = Float64(radius_m)
    electrode = Float64(electrode_radius_m)
    field = abs(Float64(voltage_v)) / max(radius, electrode)
    raw_radius = if field > Float64(critical_field_v_per_m)
        radius + Float64(step_s) * Float64(expansion_rate_m_per_v_s) * (field - Float64(critical_field_v_per_m))
    else
        radius - Float64(step_s) * Float64(recovery_rate_per_s) * (radius - electrode)
    end
    next_radius = clamp(raw_radius, electrode, Float64(maximum_ionized_radius_m))
    conductance = next_radius / (electrode * Float64(linear_resistance_ohm))
    return (radius_m=next_radius, conductance_s=conductance, current_a=conductance * Float64(voltage_v), field_v_per_m=field)
end

"""Decompose or reconstruct oriented multiconductor traveling waves from V and I."""
function independent_traveling_wave_state(
    characteristic_impedance_ohm::AbstractMatrix{<:Real},
    voltage_v::AbstractVector{<:Real},
    current_a::AbstractVector{<:Real},
)
    impedance = Matrix{Float64}(characteristic_impedance_ohm)
    voltage = Float64.(voltage_v)
    current = Float64.(current_a)
    forward = 0.5 .* (voltage .+ impedance * current)
    reverse = voltage .- forward
    return (forward_voltage_v=forward, reverse_voltage_v=reverse, reconstructed_current_a=impedance \ (forward .- reverse))
end

"""Solve the termination boundary equations for reflected and transmitted voltage waves."""
function independent_traveling_wave_reflection(
    characteristic_impedance_ohm::AbstractMatrix{<:Real},
    terminating_impedance_ohm::AbstractMatrix{<:Real},
    incident_voltage_v::AbstractVector{<:Real},
)
    characteristic = Matrix{Float64}(characteristic_impedance_ohm)
    termination = Matrix{Float64}(terminating_impedance_ohm)
    incident = Float64.(incident_voltage_v)
    reflected = (termination - characteristic) * ((termination + characteristic) \ incident)
    return (reflected_voltage_v=reflected, transmitted_voltage_v=incident + reflected)
end

"""Integrate polarity-separated disruptive effect using endpoint stresses."""
function independent_disruptive_effect_step(
    positive_effect::Real,
    negative_effect::Real,
    previous_voltage_v::Real,
    voltage_v::Real,
    elapsed_s::Real;
    positive_threshold_voltage_v::Real,
    negative_threshold_voltage_v::Real,
    positive_exponent::Real,
    negative_exponent::Real,
)
    increment(voltage) = voltage >= 0.0 ? (
        max(voltage - Float64(positive_threshold_voltage_v), 0.0)^Float64(positive_exponent), 0.0,
    ) : (
        0.0, max(-voltage - Float64(negative_threshold_voltage_v), 0.0)^Float64(negative_exponent),
    )
    old_positive, old_negative = increment(Float64(previous_voltage_v))
    new_positive, new_negative = increment(Float64(voltage_v))
    elapsed = Float64(elapsed_s)
    return (
        positive=Float64(positive_effect) + 0.5 * elapsed * (old_positive + new_positive),
        negative=Float64(negative_effect) + 0.5 * elapsed * (old_negative + new_negative),
    )
end

"""Advance a polarity-aware leader length by trapezoidal endpoint velocities."""
function independent_leader_progression_step(
    leader_length_m::Real,
    previous_voltage_v::Real,
    voltage_v::Real,
    elapsed_s::Real;
    gap_length_m::Real,
    positive_inception_field_v_per_m::Real,
    negative_inception_field_v_per_m::Real,
    positive_velocity_coefficient::Real,
    negative_velocity_coefficient::Real,
    velocity_exponent::Real,
)
    length_now = Float64(leader_length_m)
    gap = Float64(gap_length_m)
    velocity(voltage) = begin
        polarity = voltage >= 0.0 ? 1 : -1
        field = abs(voltage) / max(gap - length_now, eps(Float64))
        inception = polarity > 0 ? Float64(positive_inception_field_v_per_m) : Float64(negative_inception_field_v_per_m)
        coefficient = polarity > 0 ? Float64(positive_velocity_coefficient) : Float64(negative_velocity_coefficient)
        (value=coefficient * max(field - inception, 0.0)^Float64(velocity_exponent), polarity=polarity, field=field, inception=inception)
    end
    old = velocity(Float64(previous_voltage_v))
    new = velocity(Float64(voltage_v))
    next_length = min(gap, length_now + 0.5 * Float64(elapsed_s) * (old.value + new.value))
    polarity = new.value >= old.value ? new.polarity : old.polarity
    return (length_m=next_length, polarity=polarity, incepted=max(old.value, new.value) > 0.0, flashed=next_length >= gap)
end

"""Evaluate the hysteretic corona charge law and its differential capacitance."""
function independent_corona_charge(
    voltage_v::Real,
    previously_active::Bool;
    base_capacitance_f::Real,
    incremental_capacitance_f_per_v::Real,
    onset_voltage_v::Real,
    extinction_voltage_v::Real,
)
    voltage = Float64(voltage_v)
    magnitude = abs(voltage)
    active = previously_active ? magnitude > Float64(extinction_voltage_v) : magnitude >= Float64(onset_voltage_v)
    excess = active ? max(magnitude - Float64(extinction_voltage_v), 0.0) : 0.0
    charge = Float64(base_capacitance_f) * magnitude + 0.5 * Float64(incremental_capacitance_f_per_v) * excess^2
    capacitance = Float64(base_capacitance_f) + Float64(incremental_capacitance_f_per_v) * excess
    return (charge_c=copysign(charge, voltage), differential_capacitance_f=capacitance, active=active)
end

"""Form finite-length GIS/GIL series impedance and shunt admittance matrices."""
function independent_gis_gil_matrices(
    resistance_ohm_per_m::AbstractMatrix{<:Real},
    inductance_h_per_m::AbstractMatrix{<:Real},
    conductance_s_per_m::AbstractMatrix{<:Real},
    capacitance_f_per_m::AbstractMatrix{<:Real},
    length_m::Real,
    frequency_hz::Real,
)
    angular_frequency = 2.0 * pi * Float64(frequency_hz)
    length = Float64(length_m)
    return (
        series_impedance_ohm=length .* (Matrix{Float64}(resistance_ohm_per_m) .+ im * angular_frequency .* Matrix{Float64}(inductance_h_per_m)),
        shunt_admittance_s=length .* (Matrix{Float64}(conductance_s_per_m) .+ im * angular_frequency .* Matrix{Float64}(capacitance_f_per_m)),
    )
end

"""Compute a Wilson binomial interval for a supplied normal quantile."""
function independent_wilson_interval(failures::Integer, samples::Integer, normal_quantile::Real)
    count = Int(samples)
    failed = Int(failures)
    0 <= failed <= count && count > 0 || throw(ArgumentError("independent binomial counts are invalid"))
    z = _independent_surge_positive(normal_quantile, "normal quantile")
    estimate = failed / count
    denominator = 1.0 + z^2 / count
    centre = (estimate + z^2 / (2.0 * count)) / denominator
    half_width = z / denominator * sqrt(estimate * (1.0 - estimate) / count + z^2 / (4.0 * count^2))
    lower = iszero(failed) ? 0.0 : max(centre - half_width, 0.0)
    upper = failed == count ? 1.0 : min(centre + half_width, 1.0)
    return (probability=estimate, lower=lower, upper=upper)
end
