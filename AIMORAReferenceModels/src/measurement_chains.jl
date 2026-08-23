export IndependentMeasurementSample,
       independent_instrument_transformer_trapezoidal_step,
       independent_cvt_trapezoidal_residuals,
       independent_cvt_metrics,
       independent_analog_filter_trapezoidal_step,
       independent_uniform_measurement_quantizer,
       independent_measurement_acquisition,
       independent_sliding_rms,
       independent_fundamental_rms_phasor,
       independent_measurement_sequence_components,
       independent_positive_sequence_frequency,
       independent_comtrade_scale_and_time,
       independent_comtrade_ascii_bytes,
       independent_comtrade_binary32_bytes,
       independent_comtrade_signature

function _independent_finite_vector(values, label::AbstractString)
    vector = Float64.(values)
    all(isfinite, vector) || throw(ArgumentError("independent $label must be finite"))
    return vector
end

function _independent_finite_matrix(values, label::AbstractString)
    matrix = Matrix{Float64}(values)
    all(isfinite, matrix) || throw(ArgumentError("independent $label must be finite"))
    return matrix
end

"""Advance a reciprocal multiwinding R-L instrument model with a directly derived trapezoidal recurrence."""
function independent_instrument_transformer_trapezoidal_step(
    previous_current_a,
    previous_voltage_v,
    terminal_voltage_v,
    resistance_ohm,
    inductance_h,
    timestep_s::Real;
    winding_turns=ones(length(previous_current_a)),
    core_mmf_at::Real=0.0,
)
    previous_current = _independent_finite_vector(
        previous_current_a,
        "instrument previous current",
    )
    previous_voltage = _independent_finite_vector(
        previous_voltage_v,
        "instrument previous voltage",
    )
    terminal_voltage = _independent_finite_vector(
        terminal_voltage_v,
        "instrument terminal voltage",
    )
    resistance = _independent_finite_matrix(resistance_ohm, "instrument resistance")
    inductance = _independent_finite_matrix(inductance_h, "instrument inductance")
    turns = _independent_finite_vector(winding_turns, "instrument winding turns")
    winding_count = length(previous_current)
    length(previous_voltage) == winding_count &&
        length(terminal_voltage) == winding_count && length(turns) == winding_count ||
        throw(DimensionMismatch("independent instrument vectors must share one winding count"))
    size(resistance) == (winding_count, winding_count) &&
        size(inductance) == (winding_count, winding_count) || throw(DimensionMismatch(
        "independent instrument matrices must match the winding count",
    ))
    resistance ≈ transpose(resistance) || throw(ArgumentError(
        "independent instrument resistance must be reciprocal",
    ))
    inductance ≈ transpose(inductance) || throw(ArgumentError(
        "independent instrument inductance must be reciprocal",
    ))
    minimum(eigvals(Symmetric(resistance))) >= -1.0e-12 || throw(ArgumentError(
        "independent instrument resistance must be passive",
    ))
    minimum(eigvals(Symmetric(inductance))) > 0.0 || throw(ArgumentError(
        "independent instrument inductance must be positive definite",
    ))
    timestep = Float64(timestep_s)
    isfinite(timestep) && timestep > 0.0 || throw(ArgumentError(
        "independent instrument timestep must be finite and positive",
    ))
    core_mmf = Float64(core_mmf_at)
    isfinite(core_mmf) || throw(ArgumentError("independent core MMF must be finite"))
    inductive_resistance = 2.0 .* inductance ./ timestep
    current = (resistance + inductive_resistance) \
        (terminal_voltage + previous_voltage +
         (inductive_resistance - resistance) * previous_current)
    average_current = 0.5 .* (previous_current .+ current)
    average_voltage = 0.5 .* (previous_voltage .+ terminal_voltage)
    constitutive_residual = inductance * (current - previous_current) .-
        timestep .* (average_voltage - resistance * average_current)
    previous_energy = 0.5 * dot(previous_current, inductance * previous_current)
    stored_energy = 0.5 * dot(current, inductance * current)
    supplied_energy = timestep * dot(average_voltage, average_current)
    dissipated_energy = timestep * dot(average_current, resistance * average_current)
    energy_residual = supplied_energy - dissipated_energy -
        (stored_energy - previous_energy)
    return (
        current_a=current,
        flux_linkage_wb_turn=inductance * current,
        ampere_turn_residual_at=dot(turns, current) - core_mmf,
        constitutive_residual_vs=constitutive_residual,
        stored_energy_j=stored_energy,
        supplied_energy_j=supplied_energy,
        dissipated_energy_j=dissipated_energy,
        energy_residual_j=energy_residual,
    )
end

"""Evaluate independently assembled trapezoidal CVT branch and KCL residuals."""
function independent_cvt_trapezoidal_residuals(
    incidence,
    branch_kinds,
    resistance_ohm,
    inductance_h,
    capacitance_f,
    previous_node_voltage_v,
    node_voltage_v,
    previous_branch_current_a,
    branch_current_a,
    timestep_s::Real,
)
    graph = _independent_finite_matrix(incidence, "CVT incidence")
    kinds = Symbol.(branch_kinds)
    resistance = _independent_finite_vector(resistance_ohm, "CVT resistance")
    inductance = _independent_finite_vector(inductance_h, "CVT inductance")
    capacitance = _independent_finite_vector(capacitance_f, "CVT capacitance")
    previous_node_voltage = _independent_finite_vector(
        previous_node_voltage_v,
        "CVT previous node voltage",
    )
    node_voltage = _independent_finite_vector(node_voltage_v, "CVT node voltage")
    previous_current = _independent_finite_vector(
        previous_branch_current_a,
        "CVT previous branch current",
    )
    current = _independent_finite_vector(branch_current_a, "CVT branch current")
    branch_count = size(graph, 2)
    size(graph, 1) == length(node_voltage) == length(previous_node_voltage) ||
        throw(DimensionMismatch("independent CVT incidence and node voltages disagree"))
    all(length(values) == branch_count for values in
        (kinds, resistance, inductance, capacitance, previous_current, current)) ||
        throw(DimensionMismatch("independent CVT branch vectors disagree"))
    all(kind -> kind in (:series_rl, :resistance, :capacitance), kinds) ||
        throw(ArgumentError("independent CVT branch kind is unsupported"))
    all(>=(0.0), resistance) && all(>=(0.0), inductance) &&
        all(>=(0.0), capacitance) || throw(ArgumentError(
        "independent CVT RLC values must be nonnegative",
    ))
    timestep = Float64(timestep_s)
    isfinite(timestep) && timestep > 0.0 || throw(ArgumentError(
        "independent CVT timestep must be finite and positive",
    ))
    previous_branch_voltage = transpose(graph) * previous_node_voltage
    branch_voltage = transpose(graph) * node_voltage
    residual = zeros(branch_count)
    for branch in 1:branch_count
        if kinds[branch] === :capacitance
            capacitance[branch] > 0.0 || throw(ArgumentError(
                "independent CVT capacitor requires positive capacitance",
            ))
            residual[branch] = capacitance[branch] *
                (branch_voltage[branch] - previous_branch_voltage[branch]) -
                0.5 * timestep * (current[branch] + previous_current[branch])
        elseif kinds[branch] === :series_rl
            inductance[branch] > 0.0 || throw(ArgumentError(
                "independent CVT series-RL branch requires positive inductance",
            ))
            residual[branch] = inductance[branch] *
                (current[branch] - previous_current[branch]) -
                0.5 * timestep * (
                    branch_voltage[branch] - resistance[branch] * current[branch] +
                    previous_branch_voltage[branch] -
                    resistance[branch] * previous_current[branch]
                )
        else
            resistance[branch] > 0.0 || throw(ArgumentError(
                "independent CVT resistance branch requires positive resistance",
            ))
            residual[branch] = branch_voltage[branch] -
                resistance[branch] * current[branch]
        end
    end
    stored_energy = 0.5 * sum(
        capacitance .* abs2.(branch_voltage) + inductance .* abs2.(current),
    )
    dissipated_power = sum(resistance .* abs2.(current))
    return (
        branch_voltage_v=branch_voltage,
        constitutive_residual=residual,
        kcl_residual_a=graph * current,
        stored_energy_j=stored_energy,
        dissipated_power_w=dissipated_power,
    )
end

"""Return independent static divider, resonance, charge, and stored-energy CVT metrics."""
function independent_cvt_metrics(
    high_voltage_capacitance_f::Real,
    intermediate_voltage_capacitance_f::Real,
    compensation_inductance_h::Real;
    line_voltage_v::Real=0.0,
    divider_voltage_v::Real=0.0,
    electromagnetic_primary_voltage_v::Real=0.0,
    compensation_current_a::Real=0.0,
    suppression_capacitance_f::Real=0.0,
)
    high_capacitance, intermediate_capacitance, inductance,
        line_voltage, divider_voltage, electromagnetic_voltage,
        compensation_current, suppression_capacitance = Float64.((
            high_voltage_capacitance_f,
            intermediate_voltage_capacitance_f,
            compensation_inductance_h,
            line_voltage_v,
            divider_voltage_v,
            electromagnetic_primary_voltage_v,
            compensation_current_a,
            suppression_capacitance_f,
        ))
    all(isfinite, (
        high_capacitance,
        intermediate_capacitance,
        inductance,
        line_voltage,
        divider_voltage,
        electromagnetic_voltage,
        compensation_current,
        suppression_capacitance,
    )) || throw(ArgumentError("independent CVT metrics must be finite"))
    high_capacitance > 0.0 && intermediate_capacitance > 0.0 &&
        inductance > 0.0 && suppression_capacitance >= 0.0 || throw(ArgumentError(
        "independent CVT capacitances/inductance must be physical",
    ))
    equivalent_capacitance = inv(inv(high_capacitance) + inv(intermediate_capacitance))
    coupling_voltage = line_voltage - divider_voltage
    return (
        divider_ratio=high_capacitance / (high_capacitance + intermediate_capacitance),
        equivalent_capacitance_f=equivalent_capacitance,
        series_resonance_hz=inv(2.0 * pi * sqrt(inductance * equivalent_capacitance)),
        high_voltage_charge_c=high_capacitance * coupling_voltage,
        intermediate_charge_c=intermediate_capacitance * divider_voltage,
        stored_energy_j=0.5 * high_capacitance * coupling_voltage^2 +
            0.5 * intermediate_capacitance * divider_voltage^2 +
            0.5 * inductance * compensation_current^2 +
            0.5 * suppression_capacitance * electromagnetic_voltage^2,
    )
end

"""Advance one stable real state-space transducer/filter section by direct trapezoidal algebra."""
function independent_analog_filter_trapezoidal_step(
    previous_state,
    previous_input::Real,
    input::Real,
    state_matrix_per_s,
    input_vector_per_s,
    output_vector,
    direct_gain::Real,
    timestep_s::Real,
)
    state = _independent_finite_vector(previous_state, "analog-filter state")
    state_matrix = _independent_finite_matrix(
        state_matrix_per_s,
        "analog-filter state matrix",
    )
    input_vector = _independent_finite_vector(
        input_vector_per_s,
        "analog-filter input vector",
    )
    output = _independent_finite_vector(output_vector, "analog-filter output vector")
    previous_source, source, feedthrough, timestep = Float64.((
        previous_input,
        input,
        direct_gain,
        timestep_s,
    ))
    all(isfinite, (previous_source, source, feedthrough, timestep)) && timestep > 0.0 ||
        throw(ArgumentError("independent analog-filter scalar inputs must be finite"))
    dimension = length(state)
    size(state_matrix) == (dimension, dimension) && length(input_vector) == dimension &&
        length(output) == dimension || throw(DimensionMismatch(
        "independent analog-filter dimensions disagree",
    ))
    identity_matrix = Matrix{Float64}(I, dimension, dimension)
    next_state = (identity_matrix - 0.5 * timestep * state_matrix) \
        ((identity_matrix + 0.5 * timestep * state_matrix) * state +
         0.5 * timestep * input_vector * (previous_source + source))
    residual = next_state - state - 0.5 * timestep * (
        state_matrix * (state + next_state) +
        input_vector * (previous_source + source)
    )
    return (
        state=next_state,
        output=dot(output, next_state) + feedthrough * source,
        residual=residual,
    )
end

function _independent_round_quantizer(value::Float64, tie_rule::Symbol)
    tie_rule in (:ties_to_even, :ties_away_from_zero, :ties_toward_zero) ||
        throw(ArgumentError("independent quantizer tie rule is unsupported"))
    lower = floor(Int64, value)
    fraction = value - lower
    fraction < 0.5 && return lower
    fraction > 0.5 && return lower + 1
    tie_rule === :ties_to_even && return iseven(lower) ? lower : lower + 1
    tie_rule === :ties_away_from_zero && return value >= 0.0 ? lower + 1 : lower
    return value >= 0.0 ? lower : lower + 1
end

"""Apply clipping then an independently coded bounded uniform quantizer."""
function independent_uniform_measurement_quantizer(
    values;
    lower_limit::Real,
    upper_limit::Real,
    engineering_step::Real,
    engineering_offset::Real=0.0,
    minimum_code::Integer=typemin(Int32),
    maximum_code::Integer=typemax(Int32),
    tie_rule::Symbol=:ties_to_even,
)
    input = _independent_finite_vector(values, "quantizer values")
    lower, upper, step, offset = Float64.((
        lower_limit,
        upper_limit,
        engineering_step,
        engineering_offset,
    ))
    all(isfinite, (lower, upper, step, offset)) && lower < upper && step > 0.0 ||
        throw(ArgumentError("independent quantizer bounds and step are invalid"))
    minimum = Int64(minimum_code)
    maximum = Int64(maximum_code)
    minimum < maximum || throw(ArgumentError(
        "independent quantizer code bounds must increase",
    ))
    clipped_values = clamp.(input, lower, upper)
    clipped = BitVector(input .!= clipped_values)
    codes = Int64[
        clamp(
            _independent_round_quantizer((value - offset) / step, tie_rule),
            minimum,
            maximum,
        ) for value in clipped_values
    ]
    return (
        engineering_values=offset .+ step .* codes,
        codes,
        clipped,
    )
end

"""Compute the causal RMS of one complete ordered window."""
function independent_sliding_rms(window_values)
    window = _independent_finite_matrix(window_values, "RMS window")
    size(window, 1) > 0 || throw(ArgumentError("independent RMS window must not be empty"))
    return sqrt.(vec(sum(abs2, window; dims=1)) ./ size(window, 1))
end

"""Compute RMS phasors using a newest-first real window and the exp(+j*omega*t) convention."""
function independent_fundamental_rms_phasor(
    window_values,
    sample_times_s,
    window_weights_newest_first,
    nominal_frequency_hz::Real,
)
    window = _independent_finite_matrix(window_values, "phasor window")
    times = _independent_finite_vector(sample_times_s, "phasor sample times")
    weights = _independent_finite_vector(
        window_weights_newest_first,
        "phasor weights",
    )
    size(window, 1) == length(times) == length(weights) || throw(DimensionMismatch(
        "independent phasor window, timestamps, and weights disagree",
    ))
    frequency = Float64(nominal_frequency_hz)
    isfinite(frequency) && frequency > 0.0 || throw(ArgumentError(
        "independent phasor frequency must be finite and positive",
    ))
    coherent_gain = sum(weights)
    coherent_gain != 0.0 || throw(ArgumentError(
        "independent phasor window has zero coherent gain",
    ))
    phasors = zeros(ComplexF64, size(window, 2))
    sample_count = size(window, 1)
    for age in 0:(sample_count - 1)
        row = sample_count - age
        kernel = weights[age + 1] * cis(-2.0 * pi * frequency * times[row])
        @views phasors .+= window[row, :] .* kernel
    end
    return sqrt(2.0) .* phasors ./ coherent_gain
end

"""Transform ordered abc phasors into zero, positive, and negative sequences."""
function independent_measurement_sequence_components(phase_phasors)
    phase = ComplexF64.(phase_phasors)
    length(phase) == 3 && all(value -> isfinite(real(value)) && isfinite(imag(value)), phase) ||
        throw(DimensionMismatch("independent sequence transform requires three finite phases"))
    rotation = cis(2.0 * pi / 3.0)
    return (
        zero=(phase[1] + phase[2] + phase[3]) / 3.0,
        positive=(phase[1] + rotation * phase[2] + rotation^2 * phase[3]) / 3.0,
        negative=(phase[1] + rotation^2 * phase[2] + rotation * phase[3]) / 3.0,
    )
end

"""Estimate frequency from two positive-sequence phasors in a nominally rotating reference."""
function independent_positive_sequence_frequency(
    previous_positive::Complex,
    positive::Complex,
    elapsed_s::Real,
    nominal_frequency_hz::Real;
    minimum_magnitude::Real=0.0,
)
    previous = ComplexF64(previous_positive)
    current = ComplexF64(positive)
    elapsed, nominal, threshold = Float64.((
        elapsed_s,
        nominal_frequency_hz,
        minimum_magnitude,
    ))
    all(isfinite, (real(previous), imag(previous), real(current), imag(current),
        elapsed, nominal, threshold)) && elapsed > 0.0 && nominal > 0.0 && threshold >= 0.0 ||
        throw(ArgumentError("independent frequency inputs are invalid"))
    abs(previous) >= threshold && abs(current) >= threshold || return nothing
    return nominal + angle(current * conj(previous)) / (2.0 * pi * elapsed)
end

"""One released sample from the pure independent acquisition/delay/estimator formulation."""
struct IndependentMeasurementSample
    source_tick::Int
    release_tick::Int
    instantaneous::Vector{Float64}
    codes::Union{Nothing,Vector{Int64}}
    clipped::BitVector
    sliding_rms::Union{Nothing,Vector{Float64}}
    fundamental_rms_phasors::Union{Nothing,Vector{ComplexF64}}
    sequence_phasors::Union{Nothing,NamedTuple}
    frequency_hz::Union{Nothing,Float64}
    quality::Symbol
end

"""Enumerate exact acquisitions, integer-tick delay, hold, estimators, and quality without production scheduler/runtime code."""
function independent_measurement_acquisition(
    accepted_analog_values,
    tick_s::Real;
    sample_period_ticks::Integer,
    first_sample_tick::Integer=0,
    delay_ticks::Integer=0,
    lower_limit::Real=-floatmax(Float64),
    upper_limit::Real=floatmax(Float64),
    engineering_step=nothing,
    engineering_offset::Real=0.0,
    minimum_code::Integer=typemin(Int32),
    maximum_code::Integer=typemax(Int32),
    tie_rule::Symbol=:ties_to_even,
    window_weights_newest_first=ones(4),
    nominal_frequency_hz::Real=50.0,
    phase_order=Symbol[],
    positive_sequence_threshold::Real=0.0,
    frequency_update_separation::Integer=1,
)
    analog = _independent_finite_matrix(
        accepted_analog_values,
        "accepted analog values",
    )
    timestep = Float64(tick_s)
    isfinite(timestep) && timestep > 0.0 || throw(ArgumentError(
        "independent acquisition tick must be finite and positive",
    ))
    period = Int(sample_period_ticks)
    first_tick = Int(first_sample_tick)
    delay = Int(delay_ticks)
    period > 0 && first_tick >= 0 && delay >= 0 || throw(ArgumentError(
        "independent acquisition period, first tick, and delay are invalid",
    ))
    final_tick = size(analog, 1) - 1
    first_tick <= final_tick || return IndependentMeasurementSample[]
    weights = _independent_finite_vector(
        window_weights_newest_first,
        "acquisition window",
    )
    !isempty(weights) && sum(weights) != 0.0 || throw(ArgumentError(
        "independent acquisition window must have nonzero coherent gain",
    ))
    nominal = Float64(nominal_frequency_hz)
    threshold = Float64(positive_sequence_threshold)
    isfinite(nominal) && nominal > 0.0 && isfinite(threshold) && threshold >= 0.0 ||
        throw(ArgumentError("independent estimator settings are invalid"))
    separation = Int(frequency_update_separation)
    separation > 0 || throw(ArgumentError(
        "independent frequency update separation must be positive",
    ))
    phases = Symbol.(phase_order)
    isempty(phases) || phases == [:a, :b, :c] || throw(ArgumentError(
        "independent acquisition phase order must be absent or abc",
    ))
    size(analog, 2) == 3 || isempty(phases) || throw(DimensionMismatch(
        "independent abc acquisition requires three channels",
    ))
    released = IndependentMeasurementSample[]
    window_values = Vector{Vector{Float64}}()
    window_ticks = Int[]
    positive_history = ComplexF64[]
    positive_time_history = Float64[]
    for source_tick in first_tick:period:final_tick
        release_tick = source_tick + delay
        release_tick <= final_tick || continue
        raw = vec(copy(@view analog[source_tick + 1, :]))
        values, codes, clipped = if engineering_step === nothing
            lower = Float64(lower_limit)
            upper = Float64(upper_limit)
            isfinite(lower) && isfinite(upper) && lower < upper || throw(ArgumentError(
                "independent unquantized clip bounds are invalid",
            ))
            clipped_values = clamp.(raw, lower, upper)
            (clipped_values, nothing, BitVector(raw .!= clipped_values))
        else
            quantized = independent_uniform_measurement_quantizer(
                raw;
                lower_limit,
                upper_limit,
                engineering_step=Float64(engineering_step),
                engineering_offset,
                minimum_code,
                maximum_code,
                tie_rule,
            )
            (quantized.engineering_values, quantized.codes, quantized.clipped)
        end
        push!(window_values, copy(values))
        push!(window_ticks, source_tick)
        if length(window_values) > length(weights)
            popfirst!(window_values)
            popfirst!(window_ticks)
        end
        rms = nothing
        phasors = nothing
        sequence = nothing
        frequency = nothing
        if length(window_values) == length(weights)
            window = reduce(vcat, transpose.(window_values))
            rms = independent_sliding_rms(window)
            times = timestep .* Float64.(window_ticks)
            phasors = independent_fundamental_rms_phasor(
                window,
                times,
                weights,
                nominal,
            )
            if phases == [:a, :b, :c]
                sequence = independent_measurement_sequence_components(phasors)
                if abs(sequence.positive) >= threshold
                    push!(positive_history, sequence.positive)
                    push!(positive_time_history, source_tick * timestep)
                    required = separation + 1
                    while length(positive_history) > required
                        popfirst!(positive_history)
                        popfirst!(positive_time_history)
                    end
                    if length(positive_history) == required
                        frequency = independent_positive_sequence_frequency(
                            first(positive_history),
                            last(positive_history),
                            last(positive_time_history) - first(positive_time_history),
                            nominal;
                            minimum_magnitude=threshold,
                        )
                    end
                else
                    empty!(positive_history)
                    empty!(positive_time_history)
                end
            end
        end
        quality = rms === nothing ? :window_incomplete :
            (sequence !== nothing && frequency === nothing ?
                :frequency_unavailable : :valid)
        push!(released, IndependentMeasurementSample(
            source_tick,
            release_tick,
            values,
            codes,
            clipped,
            rms,
            phasors,
            sequence,
            frequency,
            quality,
        ))
    end
    return released
end

"""Apply independent COMTRADE engineering scaling and timestamp mapping."""
function independent_comtrade_scale_and_time(
    raw_analog_values,
    channel_scale,
    channel_offset,
    timestamp_counts,
    time_multiplier::Real,
)
    raw = _independent_finite_matrix(raw_analog_values, "COMTRADE raw values")
    scale = _independent_finite_vector(channel_scale, "COMTRADE channel scale")
    offset = _independent_finite_vector(channel_offset, "COMTRADE channel offset")
    size(raw, 2) == length(scale) == length(offset) || throw(DimensionMismatch(
        "independent COMTRADE channel scaling dimensions disagree",
    ))
    all(!=(0.0), scale) || throw(ArgumentError(
        "independent COMTRADE channel scale must be nonzero",
    ))
    timestamps = Int64.(timestamp_counts)
    length(timestamps) == size(raw, 1) && all(>=(0), timestamps) &&
        (length(timestamps) <= 1 || all(>(0), diff(timestamps))) ||
        throw(ArgumentError("independent COMTRADE timestamps must increase strictly"))
    multiplier = Float64(time_multiplier)
    isfinite(multiplier) && multiplier > 0.0 || throw(ArgumentError(
        "independent COMTRADE time multiplier must be finite and positive",
    ))
    return (
        engineering_values=raw .* transpose(scale) .+ transpose(offset),
        time_s=1.0e-6 * multiplier .* Float64.(timestamps),
    )
end

function _independent_comtrade_rows(sample_numbers, timestamp_counts, raw_analog_values, digital_values)
    samples = Int64.(sample_numbers)
    timestamps = Int64.(timestamp_counts)
    raw = Matrix{Int64}(raw_analog_values)
    digital = BitMatrix(digital_values)
    row_count = length(samples)
    length(timestamps) == row_count && size(raw, 1) == row_count &&
        size(digital, 1) == row_count || throw(DimensionMismatch(
        "independent COMTRADE row counts disagree",
    ))
    samples == collect(Int64, 1:row_count) || throw(ArgumentError(
        "independent COMTRADE sample numbers must be contiguous and one-based",
    ))
    all(>=(0), timestamps) && (row_count <= 1 || all(>(0), diff(timestamps))) ||
        throw(ArgumentError("independent COMTRADE timestamps must increase strictly"))
    return samples, timestamps, raw, digital
end

"""Serialize an independent bounded ASCII DAT record with integer raw samples."""
function independent_comtrade_ascii_bytes(
    sample_numbers,
    timestamp_counts,
    raw_analog_values,
    digital_values,
)
    samples, timestamps, raw, digital = _independent_comtrade_rows(
        sample_numbers,
        timestamp_counts,
        raw_analog_values,
        digital_values,
    )
    io = IOBuffer()
    for row in eachindex(samples)
        print(io, samples[row], ',', timestamps[row])
        for value in @view raw[row, :]
            print(io, ',', value)
        end
        for value in @view digital[row, :]
            print(io, ',', value ? 1 : 0)
        end
        print(io, '\n')
    end
    return take!(io)
end

function _independent_append_u16_little_endian!(bytes::Vector{UInt8}, value::UInt16)
    push!(bytes, UInt8(value & 0xff), UInt8((value >> 8) & 0xff))
    return bytes
end

function _independent_append_u32_little_endian!(bytes::Vector{UInt8}, value::UInt32)
    push!(
        bytes,
        UInt8(value & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 24) & 0xff),
    )
    return bytes
end

"""Serialize the registered independent little-endian BINARY32 DAT subset."""
function independent_comtrade_binary32_bytes(
    sample_numbers,
    timestamp_counts,
    raw_analog_values,
    digital_values,
)
    samples, timestamps, raw, digital = _independent_comtrade_rows(
        sample_numbers,
        timestamp_counts,
        raw_analog_values,
        digital_values,
    )
    bytes = UInt8[]
    digital_word_count = cld(size(digital, 2), 16)
    for row in eachindex(samples)
        0 <= samples[row] <= typemax(UInt32) &&
            0 <= timestamps[row] <= typemax(UInt32) || throw(ArgumentError(
            "independent COMTRADE sample/timestamp exceeds UInt32",
        ))
        _independent_append_u32_little_endian!(bytes, UInt32(samples[row]))
        _independent_append_u32_little_endian!(bytes, UInt32(timestamps[row]))
        for raw_value in @view raw[row, :]
            typemin(Int32) < raw_value <= typemax(Int32) || throw(ArgumentError(
                "independent COMTRADE BINARY32 analog value is out of range",
            ))
            _independent_append_u32_little_endian!(
                bytes,
                reinterpret(UInt32, Int32(raw_value)),
            )
        end
        for word_index in 0:(digital_word_count - 1)
            word = UInt16(0)
            for bit_index in 0:15
                channel = 16 * word_index + bit_index + 1
                channel <= size(digital, 2) || break
                digital[row, channel] && (word |= UInt16(1) << bit_index)
            end
            _independent_append_u16_little_endian!(bytes, word)
        end
    end
    return bytes
end

"""Hash independent configuration bytes, a zero separator, and DAT bytes."""
function independent_comtrade_signature(configuration_text::AbstractString, data_bytes)
    return bytes2hex(sha256(vcat(
        collect(codeunits(String(configuration_text))),
        UInt8(0),
        UInt8.(data_bytes),
    )))
end
