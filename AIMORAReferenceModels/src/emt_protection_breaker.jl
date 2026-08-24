function _independent_positive_finite(value::Real, label::AbstractString)
    converted = Float64(value)
    isfinite(converted) && converted > 0.0 || throw(ArgumentError(
        "independent $label must be finite and positive",
    ))
    return converted
end

"""Evaluate a generic sampled magnitude relay directly from its threshold and timer equations."""
function independent_magnitude_timer_trace(
    values::AbstractVector{<:Real};
    tick_s::Real,
    pickup::Real,
    dropout_ratio::Real,
    direction::Symbol=:over,
    timer_mode::Symbol=:instantaneous,
    definite_time_s::Real=0.0,
    inverse_a::Real=1.0,
    inverse_b::Real=0.0,
    inverse_p::Real=1.0,
    time_dial_s::Real=1.0,
    reset_time_s::Real=0.0,
)
    samples = Float64.(values)
    all(isfinite, samples) || throw(ArgumentError(
        "independent magnitude samples must be finite",
    ))
    step = _independent_positive_finite(tick_s, "magnitude sample period")
    threshold = _independent_positive_finite(pickup, "magnitude pickup")
    dropout = Float64(dropout_ratio)
    isfinite(dropout) && 0.0 < dropout <= 1.0 || throw(ArgumentError(
        "independent magnitude dropout ratio must be in (0, 1]",
    ))
    direction in (:over, :under) || throw(ArgumentError(
        "independent magnitude direction must be :over or :under",
    ))
    timer_mode in (:instantaneous, :definite, :inverse) || throw(ArgumentError(
        "independent magnitude timer must be instantaneous, definite, or inverse",
    ))
    definite = Float64(definite_time_s)
    inverse_coefficients = Float64.((inverse_a, inverse_b, inverse_p, time_dial_s))
    reset = Float64(reset_time_s)
    timer_mode === :definite && !(isfinite(definite) && definite > 0.0) &&
        throw(ArgumentError("independent definite time must be finite and positive"))
    timer_mode === :inverse && !(
        all(isfinite, inverse_coefficients) && inverse_coefficients[1] > 0.0 &&
        inverse_coefficients[2] >= 0.0 && inverse_coefficients[3] > 0.0 &&
        inverse_coefficients[4] > 0.0
    ) && throw(ArgumentError("independent inverse timer coefficients are invalid"))
    isfinite(reset) && reset >= 0.0 || throw(ArgumentError(
        "independent timer reset time must be finite and nonnegative",
    ))
    picked_up = false
    timer_fraction = 0.0
    trace = NamedTuple[]
    for (index, sample) in pairs(samples)
        comparison = if direction === :over
            sample >= (picked_up ? threshold * dropout : threshold)
        else
            sample <= (picked_up ? threshold / dropout : threshold)
        end
        multiple = direction === :over ? sample / threshold :
            (iszero(sample) ? Inf : threshold / sample)
        elapsed = index == firstindex(samples) ? 0.0 : step
        if !comparison
            timer_fraction = iszero(reset) ? 0.0 :
                max(0.0, timer_fraction - elapsed / reset)
        elseif timer_mode === :instantaneous
            timer_fraction = 1.0
        elseif timer_mode === :definite
            timer_fraction = min(1.0, timer_fraction + elapsed / definite)
        elseif multiple > 1.0
            operate_time = inverse_coefficients[4] * (
                inverse_coefficients[1] /
                    (multiple^inverse_coefficients[3] - 1.0) +
                inverse_coefficients[2]
            )
            isfinite(operate_time) && operate_time > 0.0 || throw(ArgumentError(
                "independent inverse operate time is outside its finite domain",
            ))
            timer_fraction = min(1.0, timer_fraction + elapsed / operate_time)
        end
        picked_up = comparison
        push!(trace, (
            sample_index=index,
            value=sample,
            pickup_multiple=multiple,
            pickup_active=picked_up,
            timer_fraction=timer_fraction,
            operated=picked_up && timer_fraction >= 1.0,
        ))
    end
    return trace
end

"""Compute the signed phasor directional torque without production relay state."""
function independent_directional_torque(
    polarizing_voltage_v::Number,
    operating_current_a::Number,
    characteristic_angle_rad::Real;
    forward_polarity::Integer=1,
)
    voltage = ComplexF64(polarizing_voltage_v)
    current = ComplexF64(operating_current_a)
    angle = Float64(characteristic_angle_rad)
    polarity = Int(forward_polarity)
    isfinite(real(voltage)) && isfinite(imag(voltage)) &&
        isfinite(real(current)) && isfinite(imag(current)) && isfinite(angle) ||
        throw(ArgumentError("independent directional inputs must be finite"))
    polarity in (-1, 1) || throw(ArgumentError(
        "independent directional polarity must be -1 or 1",
    ))
    return polarity * real(voltage * conj(current) * cis(-angle))
end

function independent_mho_margin(
    voltage_v::Number,
    current_a::Number,
    center_ohm::Number,
    radius_ohm::Real,
)
    current = ComplexF64(current_a)
    iszero(current) && throw(ArgumentError("independent mho current must be nonzero"))
    radius = _independent_positive_finite(radius_ohm, "mho radius")
    impedance = ComplexF64(voltage_v) / current
    margin = radius - abs(impedance - ComplexF64(center_ohm))
    return (impedance_ohm=impedance, margin_ohm=margin, asserted=margin >= 0.0)
end

function independent_polygon_margin(
    voltage_v::Number,
    current_a::Number,
    outward_normals::AbstractVector{<:Number},
    limits_ohm::AbstractVector{<:Real},
)
    current = ComplexF64(current_a)
    iszero(current) && throw(ArgumentError("independent polygon current must be nonzero"))
    normals = ComplexF64.(outward_normals)
    limits = Float64.(limits_ohm)
    length(normals) == length(limits) >= 3 || throw(DimensionMismatch(
        "independent polygon requires at least three matched half-planes",
    ))
    impedance = ComplexF64(voltage_v) / current
    margin = minimum(
        limit - real(conj(normal) * impedance)
        for (normal, limit) in zip(normals, limits)
    )
    return (impedance_ohm=impedance, margin_ohm=margin, asserted=margin >= 0.0)
end

function independent_biased_differential(
    terminal_currents_a::AbstractVector{<:Number};
    compensation=ones(length(terminal_currents_a)),
    restraint_mode::Symbol=:half_sum,
    minimum_operate_a::Real,
    initial_bias_a::Real=0.0,
    restraint_breakpoints_a::AbstractVector{<:Real}=Float64[],
    region_slopes::AbstractVector{<:Real},
)
    currents = ComplexF64.(terminal_currents_a)
    factors = ComplexF64.(compensation)
    length(currents) == length(factors) >= 2 || throw(DimensionMismatch(
        "independent differential terminal and compensation counts differ",
    ))
    compensated = currents .* factors
    operate = abs(sum(compensated))
    restraint = restraint_mode === :half_sum ? sum(abs, compensated) / 2.0 :
        restraint_mode === :maximum ? maximum(abs, compensated) :
        throw(ArgumentError("independent differential restraint mode is unsupported"))
    minimum_operate = Float64(minimum_operate_a)
    bias = Float64(initial_bias_a)
    breakpoints = Float64.(restraint_breakpoints_a)
    slopes = Float64.(region_slopes)
    length(slopes) == length(breakpoints) + 1 || throw(DimensionMismatch(
        "independent differential slopes do not span every region",
    ))
    threshold = bias
    lower = 0.0
    for (region, slope) in pairs(slopes)
        upper = region <= length(breakpoints) ? breakpoints[region] : restraint
        threshold += slope * max(0.0, min(restraint, upper) - lower)
        restraint <= upper && break
        lower = upper
    end
    threshold = max(minimum_operate, threshold)
    return (
        compensated_currents_a=compensated,
        operate_current_a=operate,
        restraint_current_a=restraint,
        threshold_current_a=threshold,
        margin_a=operate - threshold,
        asserted=operate >= threshold,
    )
end

function independent_rocof_trace(
    frequency_hz::AbstractVector{<:Real},
    sample_period_s::Real,
    window_intervals::Integer,
)
    frequency = Float64.(frequency_hz)
    all(isfinite, frequency) || throw(ArgumentError(
        "independent frequency trace must be finite",
    ))
    period = _independent_positive_finite(sample_period_s, "frequency sample period")
    window = Int(window_intervals)
    window > 0 || throw(ArgumentError("independent ROCOF window must be positive"))
    return Union{Nothing,Float64}[
        index <= window ? nothing :
        (frequency[index] - frequency[index - window]) / (window * period)
        for index in eachindex(frequency)
    ]
end

function independent_incremental_wave_trace(
    voltage_v::AbstractVector{<:Real},
    current_a::AbstractVector{<:Real},
    reference_impedance_ohm::Real,
)
    voltage = Float64.(voltage_v)
    current = Float64.(current_a)
    length(voltage) == length(current) || throw(DimensionMismatch(
        "independent wave voltage and current traces differ",
    ))
    impedance = _independent_positive_finite(
        reference_impedance_ohm,
        "wave reference impedance",
    )
    return [(
        sample_index=index,
        forward_wave_v=(voltage[index] - voltage[index - 1]) +
            impedance * (current[index] - current[index - 1]),
        reverse_wave_v=(voltage[index] - voltage[index - 1]) -
            impedance * (current[index] - current[index - 1]),
    ) for index in 2:length(voltage)]
end

function independent_protection_message_calendar(
    sends::AbstractVector{<:NamedTuple};
    fixed_delay_ticks::Integer,
    dropped_sequences::AbstractSet{<:Integer}=Set{Int}(),
    duplicate_copies::AbstractDict{<:Integer,<:Integer}=Dict{Int,Int}(),
    additional_delay_ticks::AbstractDict{<:Integer,<:Integer}=Dict{Int,Int}(),
)
    delay = Int(fixed_delay_ticks)
    delay >= 0 || throw(ArgumentError("independent message delay must be nonnegative"))
    deliveries = NamedTuple[]
    for (sequence, send) in pairs(sends)
        send_tick = Int(send.send_tick)
        sequence in dropped_sequences && continue
        copies = Int(get(duplicate_copies, sequence, 1))
        extra = Int(get(additional_delay_ticks, sequence, 0))
        copies > 0 && extra >= 0 || throw(ArgumentError(
            "independent message copies and additional delay are invalid",
        ))
        for copy_index in 1:copies
            push!(deliveries, (
                sequence_number=sequence,
                copy_index=copy_index,
                payload=send.payload,
                send_tick=send_tick,
                delivery_tick=send_tick + delay + extra,
            ))
        end
    end
    sort!(deliveries; by=value -> (
        value.delivery_tick,
        value.sequence_number,
        value.copy_index,
    ))
    return deliveries
end

"""Solve the three-conductance source-breaker-load divider directly by KCL."""
function independent_breaker_load_voltage(
    source_voltage_v::Real,
    source_conductance_s::Real,
    breaker_conductance_s::Real,
    load_conductance_s::Real,
)
    source = Float64(source_voltage_v)
    conductances = Float64.((
        source_conductance_s,
        breaker_conductance_s,
        load_conductance_s,
    ))
    isfinite(source) && all(value -> isfinite(value) && value > 0.0, conductances) ||
        throw(ArgumentError("independent breaker divider inputs must be finite positive"))
    source_conductance, breaker_conductance, load_conductance = conductances
    denominator = source_conductance * load_conductance +
        source_conductance * breaker_conductance +
        breaker_conductance * load_conductance
    return source * source_conductance * breaker_conductance / denominator
end

function independent_contact_energy_trace(
    voltage_v::AbstractVector{<:Real},
    current_a::AbstractVector{<:Real},
    tick_s::Real,
)
    voltage = Float64.(voltage_v)
    current = Float64.(current_a)
    length(voltage) == length(current) || throw(DimensionMismatch(
        "independent contact voltage and current traces differ",
    ))
    step = _independent_positive_finite(tick_s, "contact-energy tick")
    power = voltage .* current
    energy = zeros(length(power))
    for index in 2:length(power)
        energy[index] = energy[index - 1] +
            0.5 * (power[index - 1] + power[index]) * step
    end
    return (power_w=power, energy_j=energy)
end

function independent_breaker_failure(
    trip_tick::Integer,
    accepted_tick::Integer,
    failure_delay_ticks::Integer,
    pole_open::NTuple{3,Bool},
    pole_current_a::NTuple{3,<:Real},
    current_threshold_a::Real,
)
    trip = Int(trip_tick)
    tick = Int(accepted_tick)
    delay = Int(failure_delay_ticks)
    threshold = Float64(current_threshold_a)
    trip >= 0 && tick >= trip && delay >= 0 && isfinite(threshold) && threshold >= 0.0 ||
        throw(ArgumentError("independent breaker-failure calendar is invalid"))
    due = tick >= trip + delay
    failed = due && any(index ->
        !pole_open[index] || abs(Float64(pole_current_a[index])) > threshold,
        1:3,
    )
    return (due=due, failed=failed, backup_trip_required=failed)
end
