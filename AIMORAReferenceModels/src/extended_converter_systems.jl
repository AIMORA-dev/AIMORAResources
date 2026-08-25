function independent_dcdc_conversion_ratio(family::Symbol, duty::Real)
    d = Float64(duty)
    isfinite(d) && 0.0 < d < 1.0 || throw(ArgumentError(
        "independent DC/DC duty must lie strictly between zero and one",
    ))
    family === :buck && return d
    family === :boost && return 1.0 / (1.0 - d)
    family === :inverting_buck_boost && return -d / (1.0 - d)
    throw(ArgumentError("independent DC/DC family is unsupported"))
end

function independent_dual_active_bridge_power(
    primary_voltage_v::Real,
    secondary_voltage_v::Real,
    transformer_ratio::Real,
    phase_shift_rad::Real,
    angular_frequency_rad_per_s::Real,
    leakage_inductance_h::Real,
)
    values = Float64.((
        primary_voltage_v,
        secondary_voltage_v,
        transformer_ratio,
        phase_shift_rad,
        angular_frequency_rad_per_s,
        leakage_inductance_h,
    ))
    all(isfinite, values) || throw(ArgumentError("independent DAB inputs must be finite"))
    v1, v2, ratio, phase, omega, leakage = values
    v1 > 0.0 && v2 > 0.0 && ratio > 0.0 && omega > 0.0 && leakage > 0.0 ||
        throw(ArgumentError("independent DAB physical magnitudes must be positive"))
    abs(phase) <= pi || throw(ArgumentError("independent DAB phase shift exceeds pi"))
    return ratio * v1 * v2 / (omega * leakage) * phase * (1.0 - abs(phase) / pi)
end

struct IndependentAverageDualActiveBridgeTrace
    time_s::Vector{Float64}
    primary_dc_voltage_v::Vector{Float64}
    secondary_dc_voltage_v::Vector{Float64}
    primary_dc_current_a::Vector{Float64}
    secondary_dc_current_a::Vector{Float64}
    transferred_power_w::Vector{Float64}
    source_dissipated_energy_j::Vector{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_dual_active_bridge_trace(;
    primary_dc_voltage_v::Real,
    secondary_dc_voltage_v::Real,
    primary_source_resistance_ohm::Real,
    secondary_source_resistance_ohm::Real,
    transformer_ratio::Real,
    switching_frequency_hz::Real,
    phase_shift_rad::Real,
    leakage_inductance_h::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        primary_dc_voltage_v,
        secondary_dc_voltage_v,
        primary_source_resistance_ohm,
        secondary_source_resistance_ohm,
        transformer_ratio,
        switching_frequency_hz,
        phase_shift_rad,
        leakage_inductance_h,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent average DAB inputs must be finite",
    ))
    primary_voltage, secondary_voltage, primary_resistance, secondary_resistance,
        ratio, frequency, phase_shift, leakage, start_time, stop_time, step = values
    primary_voltage > 0.0 && secondary_voltage > 0.0 &&
        primary_resistance > 0.0 && secondary_resistance > 0.0 && ratio > 0.0 &&
        frequency > 0.0 && abs(phase_shift) <= pi && leakage > 0.0 &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 ||
        throw(ArgumentError("independent average DAB domain is invalid"))
    sample_count_real = (stop_time - start_time) / step
    sample_count = round(Int, sample_count_real) + 1
    isapprox(sample_count_real, sample_count - 1; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent average DAB horizon must contain integer steps"))
    power = independent_dual_active_bridge_power(
        primary_voltage,
        secondary_voltage,
        ratio,
        phase_shift,
        2.0 * pi * frequency,
        leakage,
    )
    function port_current(source_voltage, source_resistance, terminal_power)
        discriminant = source_voltage^2 - 4.0 * source_resistance * terminal_power
        discriminant >= 0.0 || throw(ArgumentError(
            "independent average DAB transfer exceeds a source power limit",
        ))
        return iszero(terminal_power) ? 0.0 :
            2.0 * terminal_power / (source_voltage + sqrt(discriminant))
    end
    primary_current = port_current(primary_voltage, primary_resistance, power)
    secondary_current = port_current(secondary_voltage, secondary_resistance, -power)
    primary_terminal_voltage = primary_voltage - primary_resistance * primary_current
    secondary_terminal_voltage = secondary_voltage - secondary_resistance * secondary_current
    source_loss = primary_resistance * primary_current^2 +
        secondary_resistance * secondary_current^2
    residual = primary_voltage * primary_current +
        secondary_voltage * secondary_current - source_loss
    time = [start_time + (sample - 1) * step for sample in 1:sample_count]
    return IndependentAverageDualActiveBridgeTrace(
        time,
        fill(primary_terminal_voltage, sample_count),
        fill(secondary_terminal_voltage, sample_count),
        fill(primary_current, sample_count),
        fill(secondary_current, sample_count),
        fill(power, sample_count),
        (0:(sample_count - 1)) .* (step * source_loss),
        vcat(0.0, fill(residual, sample_count - 1)),
    )
end

function independent_controlled_rectifier_average_voltage(
    phase_count::Integer,
    source_voltage_v::Real,
    firing_angle_rad::Real,
)
    count = Int(phase_count)
    voltage = Float64(source_voltage_v)
    angle = Float64(firing_angle_rad)
    count in (1, 3) || throw(ArgumentError("independent controlled bridge supports one or three phases"))
    voltage > 0.0 && isfinite(voltage) || throw(ArgumentError("independent bridge voltage must be positive"))
    0.0 <= angle <= pi && isfinite(angle) || throw(ArgumentError("independent firing angle must be zero through pi"))
    return count == 1 ? 2.0 * voltage * cos(angle) / pi :
        3.0 * sqrt(2.0) * voltage * cos(angle) / pi
end

struct IndependentLineCommutatedRectifierTrace
    time_s::Vector{Float64}
    source_voltage_v::Matrix{Float64}
    source_current_a::Matrix{Float64}
    dc_voltage_v::Vector{Float64}
    dc_current_a::Vector{Float64}
    conducting_state::BitMatrix
    stored_energy_j::Vector{Float64}
    energy_residual_j::Vector{Float64}
end

"""Independent ideal-diode state recurrence for one Graetz or one six-pulse bridge.

The formulation owns no production stamp, switch transition, or accepted-history code.
It selects the instantaneous maximum/minimum source phases and advances the physical
series R-L current with the implicit trapezoidal state equation, clamped only at the
ideal diode bridge's zero-current boundary.
"""
function independent_line_commutated_rectifier_trace(;
    phase_count::Integer,
    commutation::Symbol=:diode,
    firing_angle_rad::Real=0.0,
    group_phase_shift_rad=(0.0,),
    source_peak_voltage_v::Real,
    source_frequency_hz::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_dc_current_a::Real=0.0,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    phases = Int(phase_count)
    phases in (1, 3) || throw(ArgumentError(
        "independent line-commutated rectifier supports one or three phases",
    ))
    commutation in (:diode, :thyristor, :half_controlled) || throw(ArgumentError(
        "independent rectifier commutation must be diode, thyristor, or half controlled",
    ))
    group_shifts = Float64.(group_phase_shift_rad)
    !isempty(group_shifts) && length(group_shifts) <= 4 &&
        all(isfinite, group_shifts) && iszero(first(group_shifts)) &&
        length(unique(group_shifts)) == length(group_shifts) || throw(ArgumentError(
            "independent rectifier group phase shifts are invalid",
        ))
    phases == 1 && length(group_shifts) != 1 && throw(ArgumentError(
        "independent single-phase rectifier supports one bridge group",
    ))
    values = Float64.((
        firing_angle_rad,
        source_peak_voltage_v,
        source_frequency_hz,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        initial_dc_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent line-commutated rectifier inputs must be finite",
    ))
    firing_angle, peak, frequency, source_resistance, load_resistance, inductance,
        initial_current, start_time, stop_time, step = values
    0.0 <= firing_angle <= pi || throw(ArgumentError(
        "independent rectifier firing angle must lie from zero through pi",
    ))
    peak > 0.0 && frequency > 0.0 && source_resistance > 0.0 &&
        load_resistance > 0.0 && inductance > 0.0 && initial_current >= 0.0 &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 ||
        throw(ArgumentError(
            "independent line-commutated rectifier physical domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent line-commutated rectifier horizon must contain integer steps",
        ))
    sample_count = step_count + 1
    source_channel_count = phases == 1 ? 1 : 3 * length(group_shifts)
    valve_count = phases == 1 ? 4 : 6 * length(group_shifts)
    time = [start_time + index * step for index in 0:step_count]
    source_voltage = Matrix{Float64}(undef, source_channel_count, sample_count)
    source_current = zeros(Float64, source_channel_count, sample_count)
    dc_voltage = Vector{Float64}(undef, sample_count)
    dc_current = Vector{Float64}(undef, sample_count)
    conducting = falses(valve_count, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    energy_residual = zeros(Float64, sample_count)
    phase_values(sample_time) = phases == 1 ?
        [peak * sin(2pi * frequency * sample_time)] :
        [peak * sin(2pi * frequency * sample_time + group_shifts[group] -
            2pi * (phase - 1) / 3)
            for group in eachindex(group_shifts) for phase in 1:3]
    path_resistance = (phases == 1 ? 1.0 : 2.0) * source_resistance
    total_resistance = path_resistance + load_resistance
    current = initial_current
    cumulative_source_energy = 0.0
    cumulative_dissipation = 0.0
    initial_energy = 0.5 * inductance * current^2
    function path_state(sample_time)
        actual = phase_values(sample_time)
        delayed = commutation === :diode ? actual :
            phase_values(sample_time - firing_angle / (2pi * frequency))
        if phases == 1
            actual_terminals = [0.5 * actual[1], -0.5 * actual[1]]
            delayed_terminals = [0.5 * delayed[1], -0.5 * delayed[1]]
        else
            actual_terminals = actual
            delayed_terminals = delayed
        end
        return_values = commutation === :half_controlled ?
            actual_terminals : delayed_terminals
        if phases == 3 && length(group_shifts) > 1
            group = argmax([
                maximum(view(return_values, (3index - 2):(3index))) -
                    minimum(view(return_values, (3index - 2):(3index)))
                for index in eachindex(group_shifts)
            ])
            offset = 3 * (group - 1)
            upper_phase = offset +
                argmax(view(delayed_terminals, (offset + 1):(offset + 3)))
            lower_phase = offset +
                argmin(view(return_values, (offset + 1):(offset + 3)))
        else
            upper_phase = argmax(delayed_terminals)
            lower_phase = argmin(return_values)
        end
        applied_voltage = actual_terminals[upper_phase] - actual_terminals[lower_phase]
        return actual, upper_phase, lower_phase, applied_voltage
    end
    _, _, _, previous_applied_voltage = path_state(time[1])
    for sample in 1:sample_count
        values_at_sample, upper_phase, lower_phase, applied_voltage =
            path_state(time[sample])
        phases == 1 ?
            (source_voltage[1, sample] = values_at_sample[1]) :
            (source_voltage[:, sample] .= values_at_sample)
        path_conducting = current > 0.0 || applied_voltage > 0.0
        conducting[2 * upper_phase - 1, sample] = path_conducting
        conducting[2 * lower_phase, sample] = path_conducting
        if phases == 1
            source_current[1, sample] = sign(values_at_sample[1]) * current
        else
            source_current[upper_phase, sample] = current
            source_current[lower_phase, sample] = -current
        end
        dc_current[sample] = current
        dc_voltage[sample] = applied_voltage - path_resistance * current
        stored_energy[sample] = 0.5 * inductance * current^2
        sample == sample_count && break
        _, _, _, next_applied_voltage = path_state(time[sample + 1])
        factor = step * total_resistance / (2.0 * inductance)
        candidate = ((1.0 - factor) * current +
            step * (previous_applied_voltage + next_applied_voltage) /
                (2.0 * inductance)) /
            (1.0 + factor)
        next_current = max(candidate, 0.0)
        cumulative_source_energy += step * 0.5 * (
            previous_applied_voltage * current + next_applied_voltage * next_current
        )
        cumulative_dissipation += step * total_resistance *
            0.5 * (current^2 + next_current^2)
        current = next_current
        energy_residual[sample + 1] = cumulative_source_energy -
            cumulative_dissipation - (0.5 * inductance * current^2 - initial_energy)
        previous_applied_voltage = next_applied_voltage
    end
    return IndependentLineCommutatedRectifierTrace(
        time,
        source_voltage,
        source_current,
        dc_voltage,
        dc_current,
        conducting,
        stored_energy,
        energy_residual,
    )
end

function independent_interleaved_carrier_phases(channel_count::Integer, initial_phase_rad::Real=0.0)
    count = Int(channel_count)
    2 <= count <= 8 || throw(ArgumentError("independent interleaving requires two through eight channels"))
    phase = Float64(initial_phase_rad)
    isfinite(phase) || throw(ArgumentError("independent initial carrier phase must be finite"))
    return mod.(phase .+ (0:(count - 1)) .* (2.0 * pi / count), 2.0 * pi)
end

function independent_matrix_converter_map(connection, input_voltage_v, output_current_a)
    size(connection) == (3, 3) || throw(DimensionMismatch("independent matrix connection must be 3x3"))
    matrix = Matrix{Bool}(connection)
    all(row -> sum(matrix[row, :]) == 1, axes(matrix, 1)) || throw(ArgumentError(
        "independent matrix state must connect each output exactly once",
    ))
    length(input_voltage_v) == 3 && length(output_current_a) == 3 ||
        throw(DimensionMismatch("independent matrix terminal vectors must contain three phases"))
    voltage = Float64.(input_voltage_v)
    current = Float64.(output_current_a)
    all(isfinite, voltage) && all(isfinite, current) || throw(ArgumentError(
        "independent matrix terminal values must be finite",
    ))
    numeric_connection = Float64.(matrix)
    return (
        output_voltage_v=numeric_connection * voltage,
        input_current_a=transpose(numeric_connection) * current,
    )
end

function independent_matrix_space_vector_state(
    input_voltage_v,
    time_s,
    output_frequency_hz,
    carrier_frequency_hz,
    modulation_index;
    output_phase_rad=0.0,
)
    voltage = Float64.(input_voltage_v)
    length(voltage) == 3 && all(isfinite, voltage) || throw(ArgumentError(
        "independent matrix modulation requires three finite input voltages",
    ))
    time, output_frequency, carrier_frequency, modulation, phase = Float64.((
        time_s,
        output_frequency_hz,
        carrier_frequency_hz,
        modulation_index,
        output_phase_rad,
    ))
    all(isfinite, (time, output_frequency, carrier_frequency, modulation, phase)) &&
        time >= 0.0 && output_frequency > 0.0 && carrier_frequency > 0.0 &&
        0.0 < modulation <= sqrt(3.0) / 2.0 || throw(ArgumentError(
            "independent matrix modulation domain is invalid",
        ))
    input_peak = sqrt(2.0 / 3.0 * dot(voltage, voltage))
    input_peak > sqrt(eps(Float64)) || throw(ArgumentError(
        "independent matrix modulation requires a nonzero input vector",
    ))
    output_angle = 2.0 * pi * output_frequency * time + phase
    reference = [modulation * input_peak *
        sin(output_angle - (phase_index - 1) * 2.0 * pi / 3.0)
        for phase_index in 1:3]
    scored = Tuple{Float64,NTuple{3,Int}}[]
    projection = Matrix{Float64}(I, 3, 3) .- fill(1.0 / 3.0, 3, 3)
    for first in 1:3, second in 1:3, third in 1:3
        selected = (first, second, third)
        connection = zeros(3, 3)
        for output in 1:3
            connection[output, selected[output]] = 1.0
        end
        phase_voltage = projection * connection * voltage
        normalized_error = sum(abs2, phase_voltage - reference) /
            max(input_peak^2, eps(Float64))
        push!(scored, (normalized_error, selected))
    end
    sort!(scored; by=value -> value)
    subslot = min(floor(Int, 8.0 * mod(carrier_frequency * time, 1.0)) + 1, 8)
    rank = (1, 2, 1, 3, 1, 4, 1, 2)[subslot]
    selected = scored[rank][2]
    connection = falses(3, 3)
    for output in 1:3
        connection[output, selected[output]] = true
    end
    return (; reference_voltage_v=reference, input_for_output=selected,
        connection, switching_vector_rank=rank, carrier_subslot=subslot)
end

struct IndependentSwitchingMatrixConverterTrace
    time_s::Vector{Float64}
    input_source_voltage_v::Matrix{Float64}
    input_terminal_voltage_v::Matrix{Float64}
    input_current_a::Matrix{Float64}
    output_reference_voltage_v::Matrix{Float64}
    output_phase_voltage_v::Matrix{Float64}
    output_phase_current_a::Matrix{Float64}
    requested_connection::Array{Bool,3}
    applied_connection::Array{Bool,3}
    commutation_stage::Matrix{UInt8}
    stored_energy_j::Vector{Float64}
    energy_residual_j::Vector{Float64}
end

function independent_switching_matrix_converter_trace(;
    input_phase_voltage_peak_v,
    input_frequency_hz,
    output_frequency_hz,
    carrier_frequency_hz,
    modulation_index,
    source_resistance_ohm,
    load_resistance_ohm,
    load_inductance_h,
    initial_output_phase_current_a=(0.0, 0.0, 0.0),
    initial_input_for_output=(1, 2, 3),
    output_phase_rad=0.0,
    start_time_s=0.0,
    stop_time_s,
    fixed_step_s,
)
    values = Float64.((input_phase_voltage_peak_v, input_frequency_hz,
        output_frequency_hz, carrier_frequency_hz, modulation_index,
        source_resistance_ohm, load_resistance_ohm, load_inductance_h,
        output_phase_rad, start_time_s, stop_time_s, fixed_step_s))
    all(isfinite, values) && all(>(0.0), values[[1, 2, 3, 4, 6, 7, 8, 12]]) &&
        0.0 < values[5] <= sqrt(3.0) / 2.0 && values[10] >= 0.0 &&
        values[11] > values[10] || throw(ArgumentError(
            "independent matrix-converter trace domain is invalid",
        ))
    input_peak, input_frequency, output_frequency, carrier_frequency, modulation,
        source_resistance, load_resistance, load_inductance, phase,
        start_time, stop_time, step = values
    count_real = (stop_time - start_time) / step
    sample_count = round(Int, count_real) + 1
    isapprox(count_real, sample_count - 1; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent matrix-converter horizon must contain integer steps",
        ))
    current = collect(Float64.(initial_output_phase_current_a))
    length(current) == 3 && all(isfinite, current) &&
        abs(sum(current)) <= 1.0e-10 * max(maximum(abs, current), 1.0) ||
        throw(ArgumentError(
            "independent matrix initial currents must be finite and sum to zero",
        ))
    applied = collect(Int.(initial_input_for_output))
    length(applied) == 3 && all(value -> value in 1:3, applied) ||
        throw(ArgumentError(
            "independent matrix initial connection must select inputs in 1:3",
        ))
    requested = copy(applied)
    outgoing = copy(applied)
    incoming = copy(applied)
    stage = zeros(UInt8, 3)
    time = [start_time + (sample - 1) * step for sample in 1:sample_count]
    source_voltage = Matrix{Float64}(undef, 3, sample_count)
    terminal_voltage = similar(source_voltage)
    input_current = similar(source_voltage)
    reference_voltage = similar(source_voltage)
    output_voltage = similar(source_voltage)
    output_current = similar(source_voltage)
    requested_connection = falses(3, 3, sample_count)
    applied_connection = falses(3, 3, sample_count)
    stages = zeros(UInt8, 3, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    residual = zeros(sample_count)
    projection = Matrix{Float64}(I, 3, 3) .- fill(1.0 / 3.0, 3, 3)
    source_at(time_s) = [input_peak *
        sin(2.0 * pi * input_frequency * time_s - (index - 1) * 2.0 * pi / 3.0)
        for index in 1:3]
    electrical_input(output) = stage[output] == 0x00 ? applied[output] :
        stage[output] >= 0x04 ? incoming[output] : outgoing[output]
    function connection_matrix()
        matrix = zeros(3, 3)
        for output in 1:3
            matrix[output, electrical_input(output)] = 1.0
        end
        return matrix
    end
    function record!(sample)
        emf = source_at(time[sample])
        connection = connection_matrix()
        source_current = transpose(connection) * current
        input_terminal = emf - source_resistance .* source_current
        phase_voltage = projection * connection * input_terminal
        modulation_state = independent_matrix_space_vector_state(
            input_terminal, time[sample], output_frequency, carrier_frequency,
            modulation; output_phase_rad=phase)
        source_voltage[:, sample] .= emf
        terminal_voltage[:, sample] .= input_terminal
        input_current[:, sample] .= source_current
        reference_voltage[:, sample] .= modulation_state.reference_voltage_v
        output_voltage[:, sample] .= phase_voltage
        output_current[:, sample] .= current
        for output in 1:3
            requested_connection[output, requested[output], sample] = true
            applied_connection[output, electrical_input(output), sample] = true
        end
        stages[:, sample] .= stage
        stored_energy[sample] = 0.5 * load_inductance * dot(current, current)
        return (; emf, source_current)
    end
    previous_power = record!(1)
    for sample in 2:sample_count
        endpoint = time[sample]
        input_terminal_guess = terminal_voltage[:, sample - 1]
        modulation_state = independent_matrix_space_vector_state(
            input_terminal_guess, endpoint, output_frequency, carrier_frequency,
            modulation; output_phase_rad=phase)
        requested .= modulation_state.input_for_output
        for output in 1:3
            if stage[output] == 0x05
                applied[output] = incoming[output]
                stage[output] = 0x00
            elseif stage[output] != 0x00
                stage[output] += 0x01
            end
            if stage[output] == 0x00 && requested[output] != applied[output]
                outgoing[output] = applied[output]
                incoming[output] = requested[output]
                stage[output] = 0x01
            end
        end
        connection = connection_matrix()
        coupling = projection * connection * transpose(connection)
        damping = load_resistance .* Matrix{Float64}(I, 3, 3) .+
            source_resistance .* coupling
        previous_emf = source_at(time[sample - 1])
        endpoint_emf = source_at(endpoint)
        initial_source_current = transpose(connection) * current
        left = Matrix{Float64}(I, 3, 3) .+ step / (2.0 * load_inductance) .* damping
        right = (Matrix{Float64}(I, 3, 3) .-
            step / (2.0 * load_inductance) .* damping) * current +
            step / (2.0 * load_inductance) .* projection * connection *
            (previous_emf + endpoint_emf)
        previous_current = copy(current)
        previous_energy = 0.5 * load_inductance * dot(previous_current, previous_current)
        current .= projection * (left \ right)
        final = record!(sample)
        average_input_power = 0.5 * (
            dot(previous_emf, initial_source_current) +
            dot(final.emf, final.source_current)
        )
        average_source_loss = 0.5 * source_resistance * (
            dot(initial_source_current, initial_source_current) +
            dot(final.source_current, final.source_current)
        )
        average_load_loss = 0.5 * load_resistance * (
            dot(previous_current, previous_current) + dot(current, current)
        )
        residual[sample] = step * (average_input_power - average_source_loss -
            average_load_loss) - (stored_energy[sample] - previous_energy)
        previous_power = final
    end
    return IndependentSwitchingMatrixConverterTrace(
        time, source_voltage, terminal_voltage, input_current, reference_voltage,
        output_voltage, output_current, requested_connection, applied_connection,
        stages, stored_energy, residual,
    )
end

struct IndependentSwitchingCycloconverterTrace
    time_s::Vector{Float64}
    source_voltage_v::Matrix{Float64}
    source_current_a::Matrix{Float64}
    output_reference_voltage_v::Matrix{Float64}
    output_voltage_v::Matrix{Float64}
    output_current_a::Matrix{Float64}
    firing_angle_rad::Matrix{Float64}
    requested_bridge_group::Matrix{Int8}
    active_bridge_group::Matrix{Int8}
    failed_commutation::BitMatrix
    stored_energy_j::Vector{Float64}
    energy_residual_j::Vector{Float64}
end

function independent_switching_cycloconverter_trace(;
    phase_count,
    input_phase_voltage_peak_v,
    input_frequency_hz,
    output_frequency_hz,
    modulation_index,
    source_resistance_ohm,
    load_resistance_ohm,
    load_inductance_h,
    initial_output_current_a=nothing,
    initial_active_bridge_group=nothing,
    output_phase_rad=0.0,
    current_zero_tolerance_a=1.0e-6,
    start_time_s=0.0,
    stop_time_s,
    fixed_step_s,
)
    outputs = Int(phase_count)
    outputs in (1, 3) || throw(ArgumentError(
        "independent cycloconverter requires one or three outputs",
    ))
    values = Float64.((input_phase_voltage_peak_v, input_frequency_hz,
        output_frequency_hz, modulation_index, source_resistance_ohm,
        load_resistance_ohm, load_inductance_h, output_phase_rad,
        current_zero_tolerance_a, start_time_s, stop_time_s, fixed_step_s))
    all(isfinite, values) && all(>(0.0), values[[1, 2, 3, 5, 6, 7, 9, 12]]) &&
        0.0 < values[4] <= 1.0 && values[3] / values[2] <= 0.5 &&
        values[10] >= 0.0 && values[11] > values[10] || throw(ArgumentError(
            "independent cycloconverter trace domain is invalid",
        ))
    input_peak, input_frequency, output_frequency, modulation,
        source_resistance, load_resistance, load_inductance, phase,
        current_tolerance, start_time, stop_time, step = values
    count_real = (stop_time - start_time) / step
    sample_count = round(Int, count_real) + 1
    isapprox(count_real, sample_count - 1; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent cycloconverter horizon must contain integer steps",
        ))
    current = initial_output_current_a === nothing ? zeros(outputs) :
        collect(Float64.(initial_output_current_a))
    length(current) == outputs && all(isfinite, current) || throw(ArgumentError(
        "independent cycloconverter initial current is incomplete",
    ))
    active = initial_active_bridge_group === nothing ? zeros(Int8, outputs) :
        collect(Int8.(initial_active_bridge_group))
    length(active) == outputs && all(value -> value in (-1, 0, 1), active) ||
        throw(ArgumentError(
            "independent cycloconverter initial bridge group is invalid",
        ))
    requested = copy(active)
    time = [start_time + (sample - 1) * step for sample in 1:sample_count]
    source_voltage = Matrix{Float64}(undef, 3 * outputs, sample_count)
    source_current = Matrix{Float64}(undef, 3 * outputs, sample_count)
    reference_voltage = Matrix{Float64}(undef, outputs, sample_count)
    output_voltage = Matrix{Float64}(undef, outputs, sample_count)
    output_current = Matrix{Float64}(undef, outputs, sample_count)
    firing_angle = Matrix{Float64}(undef, outputs, sample_count)
    requested_group = zeros(Int8, outputs, sample_count)
    active_group = zeros(Int8, outputs, sample_count)
    failed = falses(outputs, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    residual = zeros(sample_count)
    projection = Matrix{Float64}(I, outputs, outputs)
    maximum_average_voltage = 3.0 * sqrt(3.0) / pi * input_peak
    source_at(time_s) = [input_peak *
        sin(2.0 * pi * input_frequency * time_s - (index - 1) * 2.0 * pi / 3.0)
        for index in 1:3]
    secondary_sources_at(time_s) = repeat(source_at(time_s), outputs)
    reference_at(time_s) = [modulation * maximum_average_voltage *
        sin(2.0 * pi * output_frequency * time_s + phase -
            (output - 1) * 2.0 * pi / 3.0) for output in 1:outputs]
    function path_matrix(time_s, active_values)
        reference = reference_at(time_s)
        angles = [begin
            group = active_values[output] == 0 ?
                (reference[output] < 0.0 ? Int8(-1) : Int8(1)) :
                active_values[output]
            acos(clamp(group * reference[output] / maximum_average_voltage,
                -1.0, 1.0))
        end for output in eachindex(reference)]
        incidence = zeros(3 * outputs, outputs)
        for output in 1:outputs
            group = active_values[output]
            group == 0 && continue
            delayed = source_at(time_s - angles[output] /
                (2.0 * pi * input_frequency))
            upper = argmax(delayed)
            lower = argmin(delayed)
            offset = 3 * (output - 1)
            incidence[offset + upper, output] = group
            incidence[offset + lower, output] = -group
        end
        return (; incidence, reference, firing_angle_rad=angles)
    end
    function record!(sample, path, failed_values)
        emf = secondary_sources_at(time[sample])
        input_current = path.incidence * current
        input_terminal = emf - source_resistance .* input_current
        applied_output = projection * transpose(path.incidence) * input_terminal
        source_voltage[:, sample] .= emf
        source_current[:, sample] .= input_current
        reference_voltage[:, sample] .= path.reference
        output_voltage[:, sample] .= applied_output
        output_current[:, sample] .= current
        firing_angle[:, sample] .= path.firing_angle_rad
        requested_group[:, sample] .= requested
        active_group[:, sample] .= active
        failed[:, sample] .= failed_values
        stored_energy[sample] = 0.5 * load_inductance * dot(current, current)
        return (; emf, input_current)
    end
    initial_path = path_matrix(time[1], active)
    previous_power = record!(1, initial_path, falses(outputs))
    for sample in 2:sample_count
        endpoint = time[sample]
        reference = reference_at(endpoint)
        failed_values = falses(outputs)
        for output in 1:outputs
            reference_tolerance = 64.0 * eps(max(abs(reference[output]), 1.0))
            requested[output] = abs(current[output]) > current_tolerance ?
                Int8(sign(current[output])) :
                abs(reference[output]) <= reference_tolerance ?
                    (requested[output] == 0 ? Int8(1) : requested[output]) :
                    Int8(sign(reference[output]))
            if requested[output] != active[output]
                if abs(current[output]) <= current_tolerance ||
                   (active[output] != 0 && active[output] * current[output] < 0.0)
                    active[output] = requested[output]
                else
                    failed_values[output] = true
                end
            end
        end
        path = path_matrix(endpoint, active)
        previous_emf = secondary_sources_at(time[sample - 1])
        endpoint_emf = secondary_sources_at(endpoint)
        coupling = projection * transpose(path.incidence) * path.incidence
        damping = load_resistance .* Matrix{Float64}(I, outputs, outputs) .+
            source_resistance .* coupling
        left = Matrix{Float64}(I, outputs, outputs) .+
            step / (2.0 * load_inductance) .* damping
        right = (Matrix{Float64}(I, outputs, outputs) .-
            step / (2.0 * load_inductance) .* damping) * current +
            step / (2.0 * load_inductance) .* projection *
            transpose(path.incidence) * (previous_emf + endpoint_emf)
        previous_current = copy(current)
        previous_energy = 0.5 * load_inductance * dot(previous_current, previous_current)
        initial_source_current = path.incidence * previous_current
        current .= projection * (left \ right)
        final = record!(sample, path, failed_values)
        average_source_current = 0.5 .* (initial_source_current .+
            final.input_current)
        average_output_current = 0.5 .* (previous_current .+ current)
        average_source_power = dot(0.5 .* (previous_emf .+ final.emf),
            average_source_current)
        average_source_loss = source_resistance *
            dot(average_source_current, average_source_current)
        average_load_loss = load_resistance *
            dot(average_output_current, average_output_current)
        residual[sample] = step * (average_source_power - average_source_loss -
            average_load_loss) - (stored_energy[sample] - previous_energy)
        previous_power = final
    end
    return IndependentSwitchingCycloconverterTrace(
        time, source_voltage, source_current, reference_voltage, output_voltage,
        output_current, firing_angle, requested_group, active_group, failed,
        stored_energy, residual,
    )
end

function independent_converter_energy_residual(input_power, output_power, loss_power, energy_rate)
    values = Float64.((input_power, output_power, loss_power, energy_rate))
    all(isfinite, values) || throw(ArgumentError("independent energy terms must be finite"))
    values[3] >= 0.0 || throw(ArgumentError("independent converter loss must be nonnegative"))
    return values[1] - values[2] - values[3] - values[4]
end

function independent_converter_triangular_carrier(time_s, frequency_hz, phase_rad=0.0)
    time, frequency, phase = Float64.((time_s, frequency_hz, phase_rad))
    all(isfinite, (time, frequency, phase)) && time >= 0.0 && frequency > 0.0 ||
        throw(ArgumentError("independent carrier domain is invalid"))
    cycle = mod(frequency * time + phase / (2.0 * pi), 1.0)
    return cycle <= 0.5 ? 2.0 * cycle : 2.0 * (1.0 - cycle)
end

function independent_selective_harmonic_residual(angles, target, orders)
    switching_angles = Float64.(angles)
    signs = [(-1.0)^(index + 1) for index in eachindex(switching_angles)]
    return vcat(
        4.0 / pi * sum(signs .* cos.(switching_angles)) - Float64(target),
        [sum(signs .* cos.(Int(order) .* switching_angles)) for order in orders],
    )
end

function independent_nearest_level_state(reference_pu, cell_count)
    reference = Float64(reference_pu)
    count = Int(cell_count)
    level = round(Int, reference * count)
    state = fill(Int8(0), count)
    level > 0 && fill!(view(state, 1:level), Int8(1))
    level < 0 && fill!(view(state, 1:(-level)), Int8(-1))
    return (level=level, state=state, normalized_voltage=level / count)
end

function independent_dab_gate_state(
    time_s,
    switching_frequency_hz,
    phase_shift_rad;
    modulation=:single_phase_shift,
    primary_inner_phase_shift_rad=0.0,
    secondary_inner_phase_shift_rad=0.0,
)
    time, frequency, shift, primary_inner, secondary_inner = Float64.((
        time_s,
        switching_frequency_hz,
        phase_shift_rad,
        primary_inner_phase_shift_rad,
        secondary_inner_phase_shift_rad,
    ))
    all(isfinite, (time, frequency, shift, primary_inner, secondary_inner)) &&
        time >= 0.0 && frequency > 0.0 && abs(shift) <= pi &&
        0.0 <= primary_inner < pi && 0.0 <= secondary_inner < pi ||
        throw(ArgumentError("independent DAB modulation domain is invalid"))
    modulation in (:single_phase_shift, :dual_phase_shift, :triple_phase_shift) ||
        throw(ArgumentError("independent DAB modulation kind is unsupported"))
    modulation === :single_phase_shift &&
        (!iszero(primary_inner) || !iszero(secondary_inner)) &&
        throw(ArgumentError("independent single-phase-shift DAB requires zero inner shifts"))
    modulation === :dual_phase_shift &&
        (iszero(primary_inner) == iszero(secondary_inner)) &&
        throw(ArgumentError("independent dual-phase-shift DAB requires one inner shift"))
    modulation === :triple_phase_shift &&
        (iszero(primary_inner) || iszero(secondary_inner)) &&
        throw(ArgumentError("independent triple-phase-shift DAB requires two inner shifts"))
    angle = 2.0 * pi * frequency * time
    function bridge_state(bridge_angle, inner_shift)
        function upper_state(leg_angle)
            half_cycles = leg_angle / pi
            nearest_boundary = round(half_cycles)
            boundary_tolerance = 32.0 * eps(max(1.0, abs(half_cycles)))
            half_cycle_index = abs(half_cycles - nearest_boundary) <= boundary_tolerance ?
                Int(nearest_boundary) : floor(Int, half_cycles)
            return iseven(half_cycle_index)
        end
        leg_a_upper = upper_state(bridge_angle)
        leg_b_upper = iszero(inner_shift) ? !leg_a_upper :
            upper_state(bridge_angle - (pi - inner_shift))
        return BitVector((leg_a_upper, !leg_a_upper, leg_b_upper, !leg_b_upper))
    end
    return vcat(
        bridge_state(angle, primary_inner),
        bridge_state(angle - shift, secondary_inner),
    )
end

struct IndependentDualActiveBridgeTrace
    time_s::Vector{Float64}
    primary_gate_state::BitMatrix
    secondary_gate_state::BitMatrix
    primary_bridge_voltage_v::Vector{Float64}
    secondary_bridge_voltage_v::Vector{Float64}
    leakage_current_a::Vector{Float64}
    primary_dc_current_a::Vector{Float64}
    secondary_dc_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    dissipated_energy_j::Vector{Float64}
    energy_residual_j::Vector{Float64}
end

function independent_dual_active_bridge_trace(;
    primary_dc_voltage_v::Real,
    secondary_dc_voltage_v::Real,
    transformer_ratio::Real,
    leakage_resistance_ohm::Real,
    leakage_inductance_h::Real,
    switching_frequency_hz::Real,
    phase_shift_rad::Real,
    modulation=:single_phase_shift,
    primary_inner_phase_shift_rad::Real=0.0,
    secondary_inner_phase_shift_rad::Real=0.0,
    initial_leakage_current_a::Real=0.0,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        primary_dc_voltage_v,
        secondary_dc_voltage_v,
        transformer_ratio,
        leakage_resistance_ohm,
        leakage_inductance_h,
        switching_frequency_hz,
        phase_shift_rad,
        primary_inner_phase_shift_rad,
        secondary_inner_phase_shift_rad,
        initial_leakage_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent DAB trace inputs must be finite",
    ))
    primary_voltage, secondary_voltage, ratio, resistance, inductance, frequency,
        shift, primary_inner, secondary_inner, initial_current, start_time,
        stop_time, step = values
    primary_voltage > 0.0 && secondary_voltage > 0.0 && ratio > 0.0 &&
        resistance >= 0.0 && inductance > 0.0 && frequency > 0.0 &&
        abs(shift) <= pi && start_time >= 0.0 && stop_time > start_time && step > 0.0 ||
        throw(ArgumentError("independent DAB trace physical domain is invalid"))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent DAB horizon must contain integer steps"))
    sample_count = step_count + 1
    time = [start_time + sample * step for sample in 0:step_count]
    primary_gate = falses(4, sample_count)
    secondary_gate = falses(4, sample_count)
    primary_bridge_voltage = Vector{Float64}(undef, sample_count)
    secondary_bridge_voltage = Vector{Float64}(undef, sample_count)
    leakage_current = Vector{Float64}(undef, sample_count)
    primary_dc_current = Vector{Float64}(undef, sample_count)
    secondary_dc_current = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    dissipated_energy = zeros(Float64, sample_count)
    energy_residual = zeros(Float64, sample_count)
    bridge_factor(gates) = Float64(gates[1]) - Float64(gates[3])
    function gates(sample_time)
        independent_dab_gate_state(
            sample_time,
            frequency,
            shift;
            modulation,
            primary_inner_phase_shift_rad=primary_inner,
            secondary_inner_phase_shift_rad=secondary_inner,
        )
    end
    initial_gate = gates(time[1])
    primary_gate[:, 1] = initial_gate[1:4]
    secondary_gate[:, 1] = initial_gate[5:8]
    primary_bridge_voltage[1] = primary_voltage * bridge_factor(primary_gate[:, 1])
    secondary_bridge_voltage[1] = secondary_voltage * bridge_factor(secondary_gate[:, 1])
    leakage_current[1] = initial_current
    primary_dc_current[1] = bridge_factor(primary_gate[:, 1]) * initial_current
    secondary_dc_current[1] =
        -bridge_factor(secondary_gate[:, 1]) * initial_current / ratio
    stored_energy[1] = 0.5 * inductance * initial_current^2
    cumulative_source_energy = 0.0
    current = initial_current
    for sample in 2:sample_count
        gate = gates(time[sample])
        primary_gate[:, sample] = gate[1:4]
        secondary_gate[:, sample] = gate[5:8]
        primary_factor = bridge_factor(primary_gate[:, sample])
        secondary_factor = bridge_factor(secondary_gate[:, sample])
        primary_bridge_voltage[sample] = primary_voltage * primary_factor
        secondary_bridge_voltage[sample] = secondary_voltage * secondary_factor
        applied_voltage = primary_bridge_voltage[sample] -
            secondary_bridge_voltage[sample] / ratio
        if iszero(resistance)
            slope = applied_voltage / inductance
            integrated_current = current * step + 0.5 * slope * step^2
            integrated_current_squared = current^2 * step +
                current * slope * step^2 + slope^2 * step^3 / 3.0
            next_current = current + slope * step
        else
            decay_rate = resistance / inductance
            steady_current = applied_voltage / resistance
            offset = current - steady_current
            decay = exp(-decay_rate * step)
            integrated_current = steady_current * step +
                offset * (1.0 - decay) / decay_rate
            integrated_current_squared = steady_current^2 * step +
                2.0 * steady_current * offset * (1.0 - decay) / decay_rate +
                offset^2 * (1.0 - decay^2) / (2.0 * decay_rate)
            next_current = steady_current + offset * decay
        end
        cumulative_source_energy += applied_voltage * integrated_current
        dissipated_energy[sample] = dissipated_energy[sample - 1] +
            resistance * integrated_current_squared
        current = next_current
        leakage_current[sample] = current
        primary_dc_current[sample] = primary_factor * current
        secondary_dc_current[sample] = -secondary_factor * current / ratio
        stored_energy[sample] = 0.5 * inductance * current^2
        energy_residual[sample] = cumulative_source_energy - dissipated_energy[sample] -
            (stored_energy[sample] - stored_energy[1])
    end
    return IndependentDualActiveBridgeTrace(
        time,
        primary_gate,
        secondary_gate,
        primary_bridge_voltage,
        secondary_bridge_voltage,
        leakage_current,
        primary_dc_current,
        secondary_dc_current,
        stored_energy,
        dissipated_energy,
        energy_residual,
    )
end

struct IndependentAverageBuckTrace
    time_s::Vector{Float64}
    input_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    dissipated_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_buck_trace(;
    input_voltage_v::Real,
    duty::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError("independent average buck inputs must be finite"))
    input_voltage, d, source_resistance, inductor_resistance, inductance, capacitance,
        load_resistance, initial_current, initial_voltage, start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < d < 1.0 && source_resistance > 0.0 &&
        inductor_resistance >= 0.0 && inductance > 0.0 && capacitance > 0.0 &&
        load_resistance > 0.0 && initial_voltage >= 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 || throw(ArgumentError(
        "independent average buck domain is invalid",
    ))
    step_count_real = (stop_time - start_time) / step
    step_count = Int(round(step_count_real))
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent average buck horizon must contain integer steps"))
    sample_count = step_count + 1
    time = collect(range(start_time; step, length=sample_count))
    input_voltage_trace = fill(input_voltage, sample_count)
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    energy = Vector{Float64}(undef, sample_count)
    dissipated_energy = zeros(Float64, sample_count)
    capacitor_current = zeros(Float64, sample_count)
    kcl_residual = zeros(Float64, sample_count)
    energy_residual = zeros(Float64, sample_count)
    current[1] = initial_current
    voltage[1] = initial_voltage
    input_current[1] = d * initial_current
    load_current[1] = initial_voltage / load_resistance
    capacitor_current[1] = initial_current - load_current[1]
    energy[1] = 0.5 * inductance * initial_current^2 + 0.5 * capacitance * initial_voltage^2
    series_resistance = source_resistance + inductor_resistance
    state_matrix = [
        -series_resistance / inductance -1.0 / inductance
        1.0 / capacitance -1.0 / (load_resistance * capacitance)
    ]
    source_vector = [d * input_voltage / inductance, 0.0]
    left = Matrix{Float64}(I, 2, 2) - 0.5 * step * state_matrix
    right = Matrix{Float64}(I, 2, 2) + 0.5 * step * state_matrix
    state = [initial_current, initial_voltage]
    for sample in 2:sample_count
        state = left \ (right * state + step * source_vector)
        current[sample], voltage[sample] = state
        input_current[sample] = d * state[1]
        load_current[sample] = state[2] / load_resistance
        energy[sample] = 0.5 * inductance * state[1]^2 + 0.5 * capacitance * state[2]^2
        capacitor_current[sample] =
            2.0 * capacitance * (voltage[sample] - voltage[sample - 1]) / step -
            capacitor_current[sample - 1]
        kcl_residual[sample] =
            current[sample] - load_current[sample] - capacitor_current[sample]
        input_power = d * input_voltage * state[1]
        output_power = state[2]^2 / load_resistance
        loss_power = series_resistance * state[1]^2
        dissipated_energy[sample] = dissipated_energy[sample - 1] + step * loss_power
        energy_residual[sample] = independent_converter_energy_residual(
            input_power,
            output_power,
            loss_power,
            (energy[sample] - energy[sample - 1]) / step,
        )
    end
    return IndependentAverageBuckTrace(
        time,
        input_voltage_trace,
        current,
        voltage,
        input_current,
        load_current,
        energy,
        dissipated_energy,
        kcl_residual,
        energy_residual,
    )
end

struct IndependentAverageBoostTrace
    time_s::Vector{Float64}
    input_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_boost_trace(;
    input_voltage_v::Real,
    duty::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent average boost inputs must be finite",
    ))
    input_voltage, modulation_duty, source_resistance, inductor_resistance,
        inductance, capacitance, load_resistance, initial_current, initial_voltage,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < modulation_duty < 1.0 &&
        source_resistance > 0.0 && inductor_resistance >= 0.0 &&
        inductance > 0.0 && capacitance > 0.0 && load_resistance > 0.0 &&
        initial_current >= 0.0 && initial_voltage >= 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 || throw(ArgumentError(
            "independent average boost domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent average boost horizon must contain integer steps"))
    sample_count = step_count + 1
    time = [start_time + sample * step for sample in 0:step_count]
    transfer_fraction = 1.0 - modulation_duty
    series_resistance = source_resistance + inductor_resistance
    state_matrix = [
        -series_resistance / inductance -transfer_fraction / inductance
        transfer_fraction / capacitance -1.0 / (load_resistance * capacitance)
    ]
    source_vector = [input_voltage / inductance, 0.0]
    augmented = zeros(Float64, 3, 3)
    augmented[1:2, 1:2] = state_matrix
    augmented[1:2, 3] = source_vector
    exact_step = exp(step * augmented)
    transition = exact_step[1:2, 1:2]
    source_increment = exact_step[1:2, 3]
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    energy_residual = Vector{Float64}(undef, sample_count)
    state = [initial_current, initial_voltage]
    for sample in 1:sample_count
        if sample > 1
            state = transition * state + source_increment
        end
        current[sample], voltage[sample] = state
        derivative = state_matrix * state + source_vector
        load_current[sample] = state[2] / load_resistance
        stored_energy[sample] = 0.5 * inductance * state[1]^2 +
            0.5 * capacitance * state[2]^2
        kcl_residual[sample] = transfer_fraction * state[1] -
            load_current[sample] - capacitance * derivative[2]
        energy_rate = inductance * state[1] * derivative[1] +
            capacitance * state[2] * derivative[2]
        energy_residual[sample] = input_voltage * state[1] -
            load_resistance * load_current[sample]^2 -
            series_resistance * state[1]^2 - energy_rate
    end
    return IndependentAverageBoostTrace(
        time,
        fill(input_voltage, sample_count),
        current,
        voltage,
        copy(current),
        load_current,
        stored_energy,
        kcl_residual,
        energy_residual,
    )
end

struct IndependentAverageInvertingBuckBoostTrace
    time_s::Vector{Float64}
    input_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_inverting_buck_boost_trace(;
    input_voltage_v::Real,
    duty::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent average inverting buck-boost inputs must be finite",
    ))
    input_voltage, modulation_duty, source_resistance, inductor_resistance,
        inductance, capacitance, load_resistance, initial_current, initial_voltage,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < modulation_duty < 1.0 &&
        source_resistance > 0.0 && inductor_resistance >= 0.0 &&
        inductance > 0.0 && capacitance > 0.0 && load_resistance > 0.0 &&
        initial_current >= 0.0 && initial_voltage <= 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 || throw(ArgumentError(
            "independent average inverting buck-boost domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent average inverting buck-boost horizon must contain integer steps",
        ))
    sample_count = step_count + 1
    time = [start_time + sample * step for sample in 0:step_count]
    transfer_fraction = 1.0 - modulation_duty
    series_resistance = inductor_resistance + modulation_duty * source_resistance
    state_matrix = [
        -series_resistance / inductance transfer_fraction / inductance
        -transfer_fraction / capacitance -1.0 / (load_resistance * capacitance)
    ]
    source_vector = [modulation_duty * input_voltage / inductance, 0.0]
    augmented = zeros(Float64, 3, 3)
    augmented[1:2, 1:2] = state_matrix
    augmented[1:2, 3] = source_vector
    exact_step = exp(step * augmented)
    transition = exact_step[1:2, 1:2]
    source_increment = exact_step[1:2, 3]
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    energy_residual = Vector{Float64}(undef, sample_count)
    state = [initial_current, initial_voltage]
    for sample in 1:sample_count
        if sample > 1
            state = transition * state + source_increment
        end
        current[sample], voltage[sample] = state
        derivative = state_matrix * state + source_vector
        input_current[sample] = modulation_duty * state[1]
        load_current[sample] = state[2] / load_resistance
        stored_energy[sample] = 0.5 * inductance * state[1]^2 +
            0.5 * capacitance * state[2]^2
        kcl_residual[sample] = transfer_fraction * state[1] +
            load_current[sample] + capacitance * derivative[2]
        energy_rate = inductance * state[1] * derivative[1] +
            capacitance * state[2] * derivative[2]
        energy_residual[sample] = modulation_duty * input_voltage * state[1] -
            load_resistance * load_current[sample]^2 -
            series_resistance * state[1]^2 - energy_rate
    end
    return IndependentAverageInvertingBuckBoostTrace(
        time,
        fill(input_voltage, sample_count),
        current,
        voltage,
        input_current,
        load_current,
        stored_energy,
        kcl_residual,
        energy_residual,
    )
end

struct IndependentSwitchingBuckTrace
    time_s::Vector{Float64}
    blocked_state::BitVector
    gate_state::BitVector
    switch_node_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function independent_switching_buck_trace(;
    input_voltage_v::Real,
    duty::Real,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    block_intervals_s=(),
)
    values = Float64.((
        input_voltage_v,
        duty,
        carrier_frequency_hz,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent switching buck inputs must be finite",
    ))
    input_voltage, d, carrier_frequency, source_resistance, inductor_resistance,
        inductance, capacitance, load_resistance, initial_current, initial_voltage,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < d < 1.0 && carrier_frequency > 0.0 &&
        source_resistance > 0.0 && inductor_resistance >= 0.0 && inductance > 0.0 &&
        capacitance > 0.0 && load_resistance > 0.0 && initial_voltage >= 0.0 &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 || throw(ArgumentError(
        "independent switching buck domain is invalid",
    ))
    step_count_real = (stop_time - start_time) / step
    step_count = Int(round(step_count_real))
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent switching buck horizon must contain integer steps"))
    sample_count = step_count + 1
    time = collect(range(start_time; step, length=sample_count))
    block_intervals = Tuple(begin
        length(interval) == 2 || throw(ArgumentError(
            "independent switching buck block intervals require block and restart times",
        ))
        block_time, restart_time = Float64.(interval)
        isfinite(block_time) && isfinite(restart_time) &&
            start_time < block_time < restart_time <= stop_time ||
            throw(ArgumentError(
                "independent switching buck block intervals must lie inside the execution horizon",
            ))
        block_step = (block_time - start_time) / step
        restart_step = (restart_time - start_time) / step
        all(value -> isapprox(value, round(value); atol=1.0e-10, rtol=1.0e-10),
            (block_step, restart_step)) || throw(ArgumentError(
            "independent switching buck block and restart times must lie on the fixed-step calendar",
        ))
        (block_time, restart_time)
    end for interval in block_intervals_s)
    for first_index in eachindex(block_intervals), second_index in eachindex(block_intervals)
        first_index < second_index || continue
        first_interval = block_intervals[first_index]
        second_interval = block_intervals[second_index]
        max(first_interval[1], second_interval[1]) <
            min(first_interval[2], second_interval[2]) && throw(ArgumentError(
            "independent switching buck block intervals must not overlap",
        ))
    end
    blocked_state = BitVector(any(interval -> interval[1] <= sample_time < interval[2],
        block_intervals) for sample_time in time)
    gate_state = BitVector(
        !blocked_state[sample] &&
            d >= independent_converter_triangular_carrier(time[sample], carrier_frequency)
        for sample in eachindex(time)
    )
    switch_voltage = Vector{Float64}(undef, sample_count)
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    energy = Vector{Float64}(undef, sample_count)
    capacitor_current = zeros(Float64, sample_count)
    kcl_residual = zeros(Float64, sample_count)
    current[1] = initial_current
    voltage[1] = initial_voltage
    input_current[1] = gate_state[1] ? initial_current : 0.0
    switch_voltage[1] = gate_state[1] ?
        input_voltage - source_resistance * initial_current : 0.0
    load_current[1] = initial_voltage / load_resistance
    capacitor_current[1] = initial_current - load_current[1]
    energy[1] = 0.5 * inductance * initial_current^2 +
        0.5 * capacitance * initial_voltage^2
    state = [initial_current, initial_voltage]
    identity_matrix = Matrix{Float64}(I, 2, 2)
    controlled_conducting = gate_state[1]
    freewheel_conducting = false
    function trapezoidal_state(candidate_state, source_path)
        series_resistance = inductor_resistance +
            (source_path ? source_resistance : 0.0)
        state_matrix = [
            -series_resistance / inductance -1.0 / inductance
            1.0 / capacitance -1.0 / (load_resistance * capacitance)
        ]
        source_vector = [source_path ? input_voltage / inductance : 0.0, 0.0]
        left = identity_matrix - 0.5 * step * state_matrix
        right = identity_matrix + 0.5 * step * state_matrix
        return left \ (right * candidate_state + step * source_vector)
    end
    function backward_euler_half_steps(candidate_state, source_path)
        series_resistance = inductor_resistance +
            (source_path ? source_resistance : 0.0)
        state_matrix = [
            -series_resistance / inductance -1.0 / inductance
            1.0 / capacitance -1.0 / (load_resistance * capacitance)
        ]
        source_vector = [source_path ? input_voltage / inductance : 0.0, 0.0]
        half_step = step / 2.0
        left = identity_matrix - half_step * state_matrix
        first = left \ (candidate_state + half_step * source_vector)
        return left \ (first + half_step * source_vector)
    end
    function open_inductor_step(candidate_state, backward_euler)
        decay_rate = inv(load_resistance * capacitance)
        if backward_euler
            half_step = step / 2.0
            voltage_after_first = candidate_state[2] / (1.0 + half_step * decay_rate)
            return [0.0, voltage_after_first / (1.0 + half_step * decay_rate)]
        end
        numerator = 1.0 - 0.5 * step * decay_rate
        denominator = 1.0 + 0.5 * step * decay_rate
        return [0.0, candidate_state[2] * numerator / denominator]
    end
    for sample in 2:sample_count
        requested_source_path = gate_state[sample]
        previous_controlled = controlled_conducting
        previous_freewheel = freewheel_conducting
        controlled_conducting = requested_source_path
        if controlled_conducting
            freewheel_conducting = false
        elseif previous_freewheel || previous_controlled
            freewheel_candidate = trapezoidal_state(state, false)
            freewheel_conducting = freewheel_candidate[1] >= 0.0
        else
            freewheel_conducting = false
        end
        topology_changed = controlled_conducting != previous_controlled ||
            freewheel_conducting != previous_freewheel
        if controlled_conducting
            state = topology_changed ?
                backward_euler_half_steps(state, true) : trapezoidal_state(state, true)
        elseif freewheel_conducting
            state = topology_changed ?
                backward_euler_half_steps(state, false) : trapezoidal_state(state, false)
        else
            state = open_inductor_step(state, topology_changed)
        end
        current[sample], voltage[sample] = state
        input_current[sample] = controlled_conducting ? state[1] : 0.0
        switch_voltage[sample] = controlled_conducting ?
            input_voltage - source_resistance * state[1] :
            freewheel_conducting ? 0.0 : state[2]
        load_current[sample] = state[2] / load_resistance
        energy[sample] = 0.5 * inductance * state[1]^2 +
            0.5 * capacitance * state[2]^2
        capacitor_current[sample] = current[sample] - load_current[sample]
        kcl_residual[sample] =
            current[sample] - load_current[sample] - capacitor_current[sample]
    end
    return IndependentSwitchingBuckTrace(
        time,
        blocked_state,
        gate_state,
        switch_voltage,
        current,
        voltage,
        input_current,
        load_current,
        energy,
        kcl_residual,
    )
end

struct IndependentSwitchingBoostTrace
    time_s::Vector{Float64}
    gate_state::BitVector
    switch_node_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function independent_switching_boost_trace(;
    input_voltage_v::Real,
    duty::Real,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        carrier_frequency_hz,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent switching boost inputs must be finite",
    ))
    input_voltage, d, carrier_frequency, source_resistance, inductor_resistance,
        inductance, capacitance, load_resistance, initial_current, initial_voltage,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < d < 1.0 && carrier_frequency > 0.0 &&
        source_resistance > 0.0 && inductor_resistance >= 0.0 && inductance > 0.0 &&
        capacitance > 0.0 && load_resistance > 0.0 && initial_current >= 0.0 &&
        initial_voltage >= 0.0 && start_time >= 0.0 && stop_time > start_time &&
        step > 0.0 || throw(ArgumentError("independent switching boost domain is invalid"))
    step_count_real = (stop_time - start_time) / step
    step_count = Int(round(step_count_real))
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent switching boost horizon must contain integer steps"))
    sample_count = step_count + 1
    time = collect(range(start_time; step, length=sample_count))
    gate_state = BitVector(
        d >= independent_converter_triangular_carrier(sample_time, carrier_frequency)
        for sample_time in time
    )
    switch_voltage = Vector{Float64}(undef, sample_count)
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    energy = Vector{Float64}(undef, sample_count)
    capacitor_current = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    current[1] = initial_current
    voltage[1] = initial_voltage
    input_current[1] = initial_current
    switch_voltage[1] = gate_state[1] ? 0.0 : initial_voltage
    load_current[1] = initial_voltage / load_resistance
    diode_current = gate_state[1] ? 0.0 : initial_current
    capacitor_current[1] = diode_current - load_current[1]
    kcl_residual[1] = diode_current - load_current[1] - capacitor_current[1]
    energy[1] = 0.5 * inductance * initial_current^2 +
        0.5 * capacitance * initial_voltage^2
    state = [initial_current, initial_voltage]
    identity_matrix = Matrix{Float64}(I, 2, 2)
    series_resistance = source_resistance + inductor_resistance
    source_vector = [input_voltage / inductance, 0.0]
    function state_matrix(controlled_on)
        return controlled_on ? [
            -series_resistance / inductance 0.0
            0.0 -1.0 / (load_resistance * capacitance)
        ] : [
            -series_resistance / inductance -1.0 / inductance
            1.0 / capacitance -1.0 / (load_resistance * capacitance)
        ]
    end
    function trapezoidal_state(candidate_state, controlled_on)
        matrix = state_matrix(controlled_on)
        left = identity_matrix - 0.5 * step * matrix
        right = identity_matrix + 0.5 * step * matrix
        return left \ (right * candidate_state + step * source_vector)
    end
    function backward_euler_half_steps(candidate_state, controlled_on)
        matrix = state_matrix(controlled_on)
        half_step = step / 2.0
        left = identity_matrix - half_step * matrix
        first = left \ (candidate_state + half_step * source_vector)
        return left \ (first + half_step * source_vector)
    end
    previous_gate = gate_state[1]
    for sample in 2:sample_count
        controlled_on = gate_state[sample]
        topology_changed = controlled_on != previous_gate
        state = topology_changed ?
            backward_euler_half_steps(state, controlled_on) :
            trapezoidal_state(state, controlled_on)
        state[1] >= 0.0 || throw(DomainError(
            state[1],
            "independent switching boost trace left its continuous-conduction domain",
        ))
        current[sample], voltage[sample] = state
        input_current[sample] = state[1]
        switch_voltage[sample] = controlled_on ? 0.0 : state[2]
        load_current[sample] = state[2] / load_resistance
        diode_current = controlled_on ? 0.0 : state[1]
        capacitor_current[sample] = diode_current - load_current[sample]
        kcl_residual[sample] =
            diode_current - load_current[sample] - capacitor_current[sample]
        energy[sample] = 0.5 * inductance * state[1]^2 +
            0.5 * capacitance * state[2]^2
        previous_gate = controlled_on
    end
    return IndependentSwitchingBoostTrace(
        time,
        gate_state,
        switch_voltage,
        current,
        voltage,
        input_current,
        load_current,
        energy,
        kcl_residual,
    )
end

struct IndependentSwitchingInvertingBuckBoostTrace
    time_s::Vector{Float64}
    gate_state::BitVector
    switch_node_voltage_v::Vector{Float64}
    inductor_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function independent_switching_inverting_buck_boost_trace(;
    input_voltage_v::Real,
    duty::Real,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm::Real,
    inductance_h::Real,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_inductor_current_a::Real,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        carrier_frequency_hz,
        source_resistance_ohm,
        inductor_resistance_ohm,
        inductance_h,
        capacitance_f,
        load_resistance_ohm,
        initial_inductor_current_a,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent switching inverting buck-boost inputs must be finite",
    ))
    input_voltage, d, carrier_frequency, source_resistance, inductor_resistance,
        inductance, capacitance, load_resistance, initial_current, initial_voltage,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < d < 1.0 && carrier_frequency > 0.0 &&
        source_resistance > 0.0 && inductor_resistance >= 0.0 && inductance > 0.0 &&
        capacitance > 0.0 && load_resistance > 0.0 && initial_current >= 0.0 &&
        initial_voltage <= 0.0 && start_time >= 0.0 && stop_time > start_time &&
        step > 0.0 || throw(ArgumentError(
            "independent switching inverting buck-boost domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = Int(round(step_count_real))
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent switching inverting buck-boost horizon must contain integer steps",
        ))
    sample_count = step_count + 1
    time = collect(range(start_time; step, length=sample_count))
    gate_state = BitVector(
        d >= independent_converter_triangular_carrier(sample_time, carrier_frequency)
        for sample_time in time
    )
    switch_voltage = Vector{Float64}(undef, sample_count)
    current = Vector{Float64}(undef, sample_count)
    voltage = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    energy = Vector{Float64}(undef, sample_count)
    capacitor_current = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    current[1] = initial_current
    voltage[1] = initial_voltage
    input_current[1] = gate_state[1] ? initial_current : 0.0
    switch_voltage[1] = gate_state[1] ?
        input_voltage - source_resistance * initial_current : initial_voltage
    load_current[1] = initial_voltage / load_resistance
    diode_current = gate_state[1] ? 0.0 : initial_current
    capacitor_current[1] = -diode_current - load_current[1]
    kcl_residual[1] = diode_current + load_current[1] + capacitor_current[1]
    energy[1] = 0.5 * inductance * initial_current^2 +
        0.5 * capacitance * initial_voltage^2
    state = [initial_current, initial_voltage]
    identity_matrix = Matrix{Float64}(I, 2, 2)
    source_vector(controlled_on) = controlled_on ?
        [input_voltage / inductance, 0.0] : [0.0, 0.0]
    function state_matrix(controlled_on)
        return controlled_on ? [
            -(source_resistance + inductor_resistance) / inductance 0.0
            0.0 -1.0 / (load_resistance * capacitance)
        ] : [
            -inductor_resistance / inductance 1.0 / inductance
            -1.0 / capacitance -1.0 / (load_resistance * capacitance)
        ]
    end
    function trapezoidal_state(candidate_state, controlled_on)
        matrix = state_matrix(controlled_on)
        source = source_vector(controlled_on)
        left = identity_matrix - 0.5 * step * matrix
        right = identity_matrix + 0.5 * step * matrix
        return left \ (right * candidate_state + step * source)
    end
    function backward_euler_half_steps(candidate_state, controlled_on)
        matrix = state_matrix(controlled_on)
        source = source_vector(controlled_on)
        half_step = step / 2.0
        left = identity_matrix - half_step * matrix
        first = left \ (candidate_state + half_step * source)
        return left \ (first + half_step * source)
    end
    previous_gate = gate_state[1]
    for sample in 2:sample_count
        controlled_on = gate_state[sample]
        topology_changed = controlled_on != previous_gate
        state = topology_changed ?
            backward_euler_half_steps(state, controlled_on) :
            trapezoidal_state(state, controlled_on)
        state[1] >= 0.0 || throw(DomainError(
            state[1],
            "independent switching inverting buck-boost left its continuous-conduction domain",
        ))
        current[sample], voltage[sample] = state
        input_current[sample] = controlled_on ? state[1] : 0.0
        switch_voltage[sample] = controlled_on ?
            input_voltage - source_resistance * state[1] : state[2]
        load_current[sample] = state[2] / load_resistance
        diode_current = controlled_on ? 0.0 : state[1]
        capacitor_current[sample] = -diode_current - load_current[sample]
        kcl_residual[sample] =
            diode_current + load_current[sample] + capacitor_current[sample]
        energy[sample] = 0.5 * inductance * state[1]^2 +
            0.5 * capacitance * state[2]^2
        previous_gate = controlled_on
    end
    return IndependentSwitchingInvertingBuckBoostTrace(
        time,
        gate_state,
        switch_voltage,
        current,
        voltage,
        input_current,
        load_current,
        energy,
        kcl_residual,
    )
end

struct IndependentAverageFourQuadrantTrace
    time_s::Vector{Float64}
    input_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    circuit_residual_v::Vector{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_four_quadrant_trace(;
    input_voltage_v::Real,
    duty::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_load_current_a::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        duty,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        initial_load_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent average four-quadrant inputs must be finite",
    ))
    input_voltage, modulation_duty, source_resistance, load_resistance,
        load_inductance, initial_current, start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < modulation_duty < 1.0 &&
        source_resistance > 0.0 && load_resistance > 0.0 &&
        load_inductance > 0.0 && start_time >= 0.0 && stop_time > start_time &&
        step > 0.0 || throw(ArgumentError(
            "independent average four-quadrant domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent average four-quadrant horizon must contain integer steps",
        ))
    sample_count = step_count + 1
    time = [start_time + sample * step for sample in 0:step_count]
    average_polarity = 2.0 * modulation_duty - 1.0
    total_resistance = source_resistance + load_resistance
    state_rate = -total_resistance / load_inductance
    source_rate = average_polarity * input_voltage / load_inductance
    transition = exp(step * state_rate)
    equilibrium_current = -source_rate / state_rate
    current = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    output_voltage = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    circuit_residual = Vector{Float64}(undef, sample_count)
    energy_residual = Vector{Float64}(undef, sample_count)
    current[1] = initial_current
    for sample in 1:sample_count
        if sample > 1
            current[sample] = equilibrium_current +
                transition * (current[sample - 1] - equilibrium_current)
        end
        derivative = state_rate * current[sample] + source_rate
        input_current[sample] = average_polarity * current[sample]
        output_voltage[sample] = average_polarity * input_voltage -
            source_resistance * current[sample]
        stored_energy[sample] = 0.5 * load_inductance * current[sample]^2
        circuit_residual[sample] = output_voltage[sample] -
            load_resistance * current[sample] - load_inductance * derivative
        energy_rate = load_inductance * current[sample] * derivative
        energy_residual[sample] = average_polarity * input_voltage * current[sample] -
            load_resistance * current[sample]^2 -
            source_resistance * current[sample]^2 - energy_rate
    end
    return IndependentAverageFourQuadrantTrace(
        time,
        fill(input_voltage, sample_count),
        input_current,
        output_voltage,
        current,
        stored_energy,
        circuit_residual,
        energy_residual,
    )
end

const IndependentAverageSinglePhaseTwoLevelInverterTrace =
    IndependentAverageFourQuadrantTrace

function independent_average_single_phase_two_level_inverter_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_load_current_a::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        initial_load_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent average single-phase inverter inputs must be finite",
    ))
    input_voltage, modulation, frequency, phase, source_resistance,
        load_resistance, load_inductance, initial_current, start_time,
        stop_time, step = values
    input_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        source_resistance > 0.0 && load_resistance > 0.0 &&
        load_inductance > 0.0 && start_time >= 0.0 && stop_time > start_time &&
        step > 0.0 || throw(ArgumentError(
            "independent average single-phase inverter domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent average single-phase inverter horizon must contain integer steps",
        ))
    time = [start_time + sample * step for sample in 0:step_count]
    total_resistance = source_resistance + load_resistance
    decay_rate = total_resistance / load_inductance
    angular_frequency = 2.0 * pi * frequency
    source_rate = modulation * input_voltage / load_inductance
    denominator = decay_rate^2 + angular_frequency^2
    particular(time_s) = source_rate / denominator * (
        decay_rate * sin(angular_frequency * time_s + phase) -
        angular_frequency * cos(angular_frequency * time_s + phase)
    )
    initial_transient = initial_current - particular(start_time)
    current = [
        particular(time_s) + initial_transient * exp(-decay_rate * (time_s - start_time))
        for time_s in time
    ]
    polarity = modulation .* sin.(angular_frequency .* time .+ phase)
    derivative = source_rate .* sin.(angular_frequency .* time .+ phase) .-
        decay_rate .* current
    input_current = polarity .* current
    output_voltage = polarity .* input_voltage .- source_resistance .* current
    stored_energy = 0.5 .* load_inductance .* current .^ 2
    circuit_residual = output_voltage .- load_resistance .* current .-
        load_inductance .* derivative
    energy_residual = polarity .* input_voltage .* current .-
        total_resistance .* current .^ 2 .-
        load_inductance .* current .* derivative
    return IndependentAverageSinglePhaseTwoLevelInverterTrace(
        time,
        fill(input_voltage, length(time)),
        input_current,
        output_voltage,
        current,
        stored_energy,
        circuit_residual,
        energy_residual,
    )
end

struct IndependentAverageThreePhaseTwoLevelInverterTrace
    time_s::Vector{Float64}
    input_voltage_v::Vector{Float64}
    input_current_a::Vector{Float64}
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    circuit_residual_v::Matrix{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_three_phase_two_level_inverter_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        load_resistance_ohm,
        load_inductance_h,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    initial_current = Float64[value for value in initial_phase_current_a]
    all(isfinite, values) && length(initial_current) == 3 &&
        all(isfinite, initial_current) || throw(ArgumentError(
            "independent average three-phase inverter inputs must be finite",
        ))
    input_voltage, modulation, frequency, phase, resistance, inductance,
        start_time, stop_time, step = values
    input_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        resistance > 0.0 && inductance > 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 || throw(ArgumentError(
            "independent average three-phase inverter domain is invalid",
        ))
    abs(sum(initial_current)) <= 1.0e-10 * max(maximum(abs, initial_current), 1.0) ||
        throw(ArgumentError("independent three-wire initial currents must sum to zero"))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent average three-phase inverter horizon must contain integer steps",
        ))
    time = [start_time + sample * step for sample in 0:step_count]
    angular_frequency = 2.0 * pi * frequency
    amplitude = 0.5 * modulation * input_voltage
    decay_rate = resistance / inductance
    source_rate = amplitude / inductance
    denominator = decay_rate^2 + angular_frequency^2
    phase_voltage = Matrix{Float64}(undef, 3, length(time))
    phase_current = Matrix{Float64}(undef, 3, length(time))
    derivative = Matrix{Float64}(undef, 3, length(time))
    for phase_index in 1:3
        offset = phase - (phase_index - 1) * 2.0 * pi / 3.0
        particular(time_s) = source_rate / denominator * (
            decay_rate * sin(angular_frequency * time_s + offset) -
            angular_frequency * cos(angular_frequency * time_s + offset)
        )
        transient = initial_current[phase_index] - particular(start_time)
        for sample in eachindex(time)
            angle = angular_frequency * time[sample] + offset
            phase_voltage[phase_index, sample] = amplitude * sin(angle)
            phase_current[phase_index, sample] = particular(time[sample]) +
                transient * exp(-decay_rate * (time[sample] - start_time))
            derivative[phase_index, sample] = source_rate * sin(angle) -
                decay_rate * phase_current[phase_index, sample]
        end
    end
    input_current = vec(sum(phase_voltage .* phase_current; dims=1)) ./ input_voltage
    stored_energy = 0.5 .* inductance .* vec(sum(abs2, phase_current; dims=1))
    circuit_residual = phase_voltage .- resistance .* phase_current .-
        inductance .* derivative
    energy_residual = vec(sum(phase_voltage .* phase_current; dims=1)) .-
        resistance .* vec(sum(abs2, phase_current; dims=1)) .-
        inductance .* vec(sum(phase_current .* derivative; dims=1))
    return IndependentAverageThreePhaseTwoLevelInverterTrace(
        time,
        fill(input_voltage, length(time)),
        input_current,
        phase_voltage,
        phase_current,
        stored_energy,
        circuit_residual,
        energy_residual,
    )
end

struct IndependentSwitchingFourQuadrantTrace
    time_s::Vector{Float64}
    positive_command::BitVector
    output_voltage_v::Vector{Float64}
    load_current_a::Vector{Float64}
    input_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    circuit_residual_v::Vector{Float64}
end

function independent_switching_four_quadrant_trace(;
    input_voltage_v::Real,
    duty::Real,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_load_current_a::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real=0.0,
)
    values = Float64.((
        input_voltage_v,
        duty,
        carrier_frequency_hz,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        initial_load_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
        dead_time_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent four-quadrant inputs must be finite",
    ))
    input_voltage, modulation_duty, carrier_frequency, source_resistance,
        load_resistance, load_inductance, initial_current, start_time, stop_time,
        step, dead_time = values
    input_voltage > 0.0 && 0.0 < modulation_duty < 1.0 &&
        carrier_frequency > 0.0 && source_resistance > 0.0 &&
        load_resistance > 0.0 && load_inductance > 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 && dead_time >= 0.0 || throw(ArgumentError(
            "independent four-quadrant domain is invalid",
        ))
    step_count = (stop_time - start_time) / step
    isapprox(step_count, round(step_count); atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent four-quadrant horizon must contain integer steps",
        ))
    sample_count = round(Int, step_count) + 1
    time = collect(range(start_time, stop_time; length=sample_count))
    carrier(time_s) = begin
        cycle = mod(carrier_frequency * time_s, 1.0)
        cycle <= 0.5 ? 2.0 * cycle : 2.0 * (1.0 - cycle)
    end
    positive_command = BitVector(modulation_duty >= carrier(time_s) for time_s in time)
    output_voltage = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    circuit_residual = Vector{Float64}(undef, sample_count)
    bridge_polarity = Vector{Float64}(undef, sample_count)
    load_current[1] = initial_current
    bridge_polarity[1] = positive_command[1] ? 1.0 : -1.0
    function record_sample!(sample)
        polarity = bridge_polarity[sample]
        current = load_current[sample]
        output_voltage[sample] = polarity * input_voltage - source_resistance * current
        input_current[sample] = polarity * current
        stored_energy[sample] = 0.5 * load_inductance * current^2
        current_derivative = (
            polarity * input_voltage -
            (source_resistance + load_resistance) * current
        ) / load_inductance
        circuit_residual[sample] =
            output_voltage[sample] - load_resistance * current -
            load_inductance * current_derivative
    end
    record_sample!(1)
    applied_positive = positive_command[1]
    dead_time_endpoint_s = -Inf
    total_resistance = source_resistance + load_resistance
    state_rate = -total_resistance / load_inductance
    function trapezoidal_step(current, polarity)
        source_rate = polarity * input_voltage / load_inductance
        return (
            (1.0 + 0.5 * step * state_rate) * current + step * source_rate
        ) / (1.0 - 0.5 * step * state_rate)
    end
    function backward_euler_half_steps(current, polarity)
        source_rate = polarity * input_voltage / load_inductance
        half_step = step / 2.0
        denominator = 1.0 - half_step * state_rate
        first = (current + half_step * source_rate) / denominator
        return (first + half_step * source_rate) / denominator
    end
    for sample in 2:sample_count
        command_changed = positive_command[sample] != positive_command[sample - 1]
        if command_changed
            applied_positive = nothing
            dead_time_endpoint_s = time[sample] + dead_time
        end
        tolerance_s = 64.0 * eps(Float64) * max(1.0, abs(time[sample]))
        if applied_positive === nothing &&
            time[sample] >= dead_time_endpoint_s - tolerance_s
            applied_positive = positive_command[sample]
        end
        polarity = if applied_positive === nothing
            load_current[sample - 1] >= 0.0 ? -1.0 : 1.0
        else
            applied_positive ? 1.0 : -1.0
        end
        bridge_polarity[sample] = polarity
        topology_changed = command_changed || polarity != bridge_polarity[sample - 1]
        load_current[sample] = topology_changed ?
            backward_euler_half_steps(load_current[sample - 1], polarity) :
            trapezoidal_step(load_current[sample - 1], polarity)
        record_sample!(sample)
    end
    return IndependentSwitchingFourQuadrantTrace(
        time,
        positive_command,
        output_voltage,
        load_current,
        input_current,
        stored_energy,
        circuit_residual,
    )
end

const IndependentSwitchingSinglePhaseTwoLevelInverterTrace =
    IndependentSwitchingFourQuadrantTrace

function independent_switching_single_phase_two_level_inverter_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_load_current_a::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real=0.0,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        carrier_frequency_hz,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        initial_load_current_a,
        start_time_s,
        stop_time_s,
        fixed_step_s,
        dead_time_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent switching single-phase inverter inputs must be finite",
    ))
    input_voltage, modulation, frequency, phase, carrier_frequency,
        source_resistance, load_resistance, load_inductance, initial_current,
        start_time, stop_time, step, dead_time = values
    input_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        carrier_frequency > frequency && source_resistance > 0.0 &&
        load_resistance > 0.0 && load_inductance > 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 && dead_time >= 0.0 ||
        throw(ArgumentError(
            "independent switching single-phase inverter domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent switching single-phase inverter horizon must contain integer steps",
        ))
    time = [start_time + sample * step for sample in 0:step_count]
    carrier(time_s) = begin
        cycle = mod(carrier_frequency * time_s, 1.0)
        cycle <= 0.5 ? 2.0 * cycle : 2.0 * (1.0 - cycle)
    end
    duty(time_s) = 0.5 * (1.0 +
        modulation * sin(2.0 * pi * frequency * time_s + phase))
    positive_command = BitVector(duty(time_s) >= carrier(time_s) for time_s in time)
    output_voltage = Vector{Float64}(undef, length(time))
    load_current = Vector{Float64}(undef, length(time))
    input_current = Vector{Float64}(undef, length(time))
    stored_energy = Vector{Float64}(undef, length(time))
    circuit_residual = Vector{Float64}(undef, length(time))
    bridge_polarity = Vector{Float64}(undef, length(time))
    load_current[1] = initial_current
    bridge_polarity[1] = positive_command[1] ? 1.0 : -1.0
    function record_sample!(sample)
        polarity = bridge_polarity[sample]
        current = load_current[sample]
        output_voltage[sample] = polarity * input_voltage - source_resistance * current
        input_current[sample] = polarity * current
        stored_energy[sample] = 0.5 * load_inductance * current^2
        derivative = (polarity * input_voltage -
            (source_resistance + load_resistance) * current) / load_inductance
        circuit_residual[sample] = output_voltage[sample] -
            load_resistance * current - load_inductance * derivative
    end
    record_sample!(1)
    applied_positive = positive_command[1]
    dead_time_endpoint_s = -Inf
    state_rate = -(source_resistance + load_resistance) / load_inductance
    function trapezoidal_step(current, polarity)
        source_rate = polarity * input_voltage / load_inductance
        return ((1.0 + 0.5 * step * state_rate) * current + step * source_rate) /
            (1.0 - 0.5 * step * state_rate)
    end
    function backward_euler_half_steps(current, polarity)
        source_rate = polarity * input_voltage / load_inductance
        half_step = step / 2.0
        denominator = 1.0 - half_step * state_rate
        first = (current + half_step * source_rate) / denominator
        return (first + half_step * source_rate) / denominator
    end
    for sample in 2:length(time)
        command_changed = positive_command[sample] != positive_command[sample - 1]
        if command_changed
            applied_positive = nothing
            dead_time_endpoint_s = time[sample] + dead_time
        end
        tolerance_s = 64.0 * eps(Float64) * max(1.0, abs(time[sample]))
        if applied_positive === nothing &&
            time[sample] >= dead_time_endpoint_s - tolerance_s
            applied_positive = positive_command[sample]
        end
        polarity = applied_positive === nothing ?
            (load_current[sample - 1] >= 0.0 ? -1.0 : 1.0) :
            (applied_positive ? 1.0 : -1.0)
        bridge_polarity[sample] = polarity
        topology_changed = command_changed || polarity != bridge_polarity[sample - 1]
        load_current[sample] = topology_changed ?
            backward_euler_half_steps(load_current[sample - 1], polarity) :
            trapezoidal_step(load_current[sample - 1], polarity)
        record_sample!(sample)
    end
    return IndependentSwitchingSinglePhaseTwoLevelInverterTrace(
        time,
        positive_command,
        output_voltage,
        load_current,
        input_current,
        stored_energy,
        circuit_residual,
    )
end

struct IndependentSwitchingThreePhaseTwoLevelInverterTrace
    time_s::Vector{Float64}
    requested_gate_state::BitMatrix
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    input_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function independent_switching_three_phase_two_level_inverter_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real=0.0,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        carrier_frequency_hz,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        start_time_s,
        stop_time_s,
        fixed_step_s,
        dead_time_s,
    ))
    initial_current = Float64.(initial_phase_current_a)
    all(isfinite, values) && length(initial_current) == 3 &&
        all(isfinite, initial_current) || throw(ArgumentError(
            "independent switching three-phase inverter inputs must be finite",
        ))
    input_voltage, modulation, frequency, phase, carrier_frequency,
        source_resistance, load_resistance, load_inductance, start_time,
        stop_time, step, dead_time = values
    input_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        carrier_frequency > frequency && source_resistance > 0.0 &&
        load_resistance > 0.0 && load_inductance > 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 && dead_time >= 0.0 ||
        throw(ArgumentError(
            "independent switching three-phase inverter domain is invalid",
        ))
    abs(sum(initial_current)) <= 1.0e-10 * max(maximum(abs, initial_current), 1.0) ||
        throw(ArgumentError("independent three-wire initial currents must sum to zero"))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent switching three-phase inverter horizon must contain integer steps",
        ))
    time = [start_time + sample * step for sample in 0:step_count]
    carrier(time_s) = begin
        cycle = mod(carrier_frequency * time_s, 1.0)
        cycle <= 0.5 ? 2.0 * cycle : 2.0 * (1.0 - cycle)
    end
    function upper_command(phase_index, time_s)
        angle = 2.0 * pi * frequency * time_s + phase -
            (phase_index - 1) * 2.0 * pi / 3.0
        duty = 0.5 * (1.0 + modulation * sin(angle))
        return duty >= carrier(time_s)
    end
    requested = falses(6, length(time))
    for sample in eachindex(time), phase_index in 1:3
        upper = upper_command(phase_index, time[sample])
        requested[2 * phase_index - 1, sample] = upper
        requested[2 * phase_index, sample] = !upper
    end
    current = Matrix{Float64}(undef, 3, length(time))
    phase_voltage = Matrix{Float64}(undef, 3, length(time))
    input_current = Vector{Float64}(undef, length(time))
    stored_energy = Vector{Float64}(undef, length(time))
    kcl_residual = Vector{Float64}(undef, length(time))
    current[:, 1] .= initial_current
    applied_upper = Union{Nothing,Bool}[
        requested[2 * phase_index - 1, 1] for phase_index in 1:3
    ]
    dead_time_endpoint = fill(-Inf, 3)
    function effective_state(sample, phase_index, previous_current)
        applied = applied_upper[phase_index]
        applied === nothing && return previous_current >= 0.0 ? 0.0 : 1.0
        return applied ? 1.0 : 0.0
    end
    function record_sample!(sample, state)
        q = state .- sum(state) / 3.0
        dc_current = dot(state, current[:, sample])
        dc_voltage = input_voltage - source_resistance * dc_current
        phase_voltage[:, sample] .= q .* dc_voltage
        input_current[sample] = dc_current
        stored_energy[sample] =
            0.5 * load_inductance * sum(abs2, current[:, sample])
        kcl_residual[sample] = abs(sum(current[:, sample]))
    end
    initial_state = [effective_state(1, phase_index, current[phase_index, 1])
        for phase_index in 1:3]
    record_sample!(1, initial_state)
    identity3 = Matrix{Float64}(I, 3, 3)
    function state_matrices(state)
        q = state .- sum(state) / 3.0
        matrix = -load_resistance / load_inductance .* identity3 .-
            source_resistance / load_inductance .* (q * transpose(state))
        forcing = input_voltage / load_inductance .* q
        return matrix, forcing
    end
    function advance_state(previous, state, method, step_size)
        matrix, forcing = state_matrices(state)
        if method === :trapezoidal
            return (identity3 - 0.5 * step_size .* matrix) \
                ((identity3 + 0.5 * step_size .* matrix) * previous +
                 step_size .* forcing)
        end
        return (identity3 - step_size .* matrix) \
            (previous + step_size .* forcing)
    end
    previous_state = initial_state
    for sample in 2:length(time)
        command_changed = false
        for phase_index in 1:3
            upper = requested[2 * phase_index - 1, sample]
            previous_upper = requested[2 * phase_index - 1, sample - 1]
            if upper != previous_upper
                applied_upper[phase_index] = nothing
                dead_time_endpoint[phase_index] = time[sample] + dead_time
                command_changed = true
            end
            tolerance_s = 64.0 * eps(Float64) * max(1.0, abs(time[sample]))
            if applied_upper[phase_index] === nothing &&
                time[sample] >= dead_time_endpoint[phase_index] - tolerance_s
                applied_upper[phase_index] = upper
            end
        end
        state = [effective_state(sample, phase_index, current[phase_index, sample - 1])
            for phase_index in 1:3]
        topology_changed = command_changed || state != previous_state
        if topology_changed
            half_step = step / 2.0
            intermediate = advance_state(current[:, sample - 1], state, :backward_euler, half_step)
            current[:, sample] .= advance_state(intermediate, state, :backward_euler, half_step)
        else
            current[:, sample] .= advance_state(
                current[:, sample - 1],
                state,
                :trapezoidal,
                step,
            )
        end
        current[:, sample] .-= sum(current[:, sample]) / 3.0
        record_sample!(sample, state)
        previous_state = state
    end
    return IndependentSwitchingThreePhaseTwoLevelInverterTrace(
        time,
        requested,
        phase_voltage,
        current,
        input_current,
        stored_energy,
        kcl_residual,
    )
end

function _independent_npc_state_matrix(
    positive_level,
    negative_level,
    source_voltage,
    source_resistance,
    capacitance,
    load_resistance,
    load_inductance,
)
    positive = Float64.(positive_level)
    negative = Float64.(negative_level)
    length(positive) == 3 && length(negative) == 3 || throw(DimensionMismatch(
        "independent NPC state requires three positive and negative level weights",
    ))
    matrix = zeros(5, 5)
    forcing = zeros(5)
    mean_positive = sum(positive) / 3.0
    mean_negative = sum(negative) / 3.0
    for phase in 1:3
        matrix[phase, phase] = -load_resistance / load_inductance
        matrix[phase, 4] = (positive[phase] - mean_positive) / load_inductance
        matrix[phase, 5] = (-negative[phase] + mean_negative) / load_inductance
        matrix[4, phase] = -positive[phase] / capacitance
        matrix[5, phase] = negative[phase] / capacitance
    end
    link_coefficient = -inv(source_resistance * capacitance)
    matrix[4, 4] = link_coefficient
    matrix[4, 5] = link_coefficient
    matrix[5, 4] = link_coefficient
    matrix[5, 5] = link_coefficient
    forcing[4] = source_voltage / (source_resistance * capacitance)
    forcing[5] = forcing[4]
    return matrix, forcing
end

function _independent_npc_observables(
    state,
    positive_level,
    neutral_level,
    negative_level,
    source_voltage,
    source_resistance,
    capacitance,
    load_inductance,
)
    current = view(state, 1:3)
    upper_voltage = state[4]
    lower_voltage = state[5]
    pole_voltage = [
        positive_level[phase] * upper_voltage -
            negative_level[phase] * lower_voltage
        for phase in 1:3
    ]
    phase_voltage = pole_voltage .- sum(pole_voltage) / 3.0
    source_current = (source_voltage - upper_voltage - lower_voltage) / source_resistance
    midpoint_current = sum(neutral_level .* current)
    stored_energy = 0.5 * load_inductance * sum(abs2, current) +
        0.5 * capacitance * (upper_voltage^2 + lower_voltage^2)
    return (
        phase_voltage=phase_voltage,
        source_current=source_current,
        midpoint_current=midpoint_current,
        stored_energy=stored_energy,
    )
end

function _independent_npc_inputs(
    input_voltage_v,
    modulation_index,
    fundamental_frequency_hz,
    phase_rad,
    source_resistance_ohm,
    dc_link_capacitance_f,
    load_resistance_ohm,
    load_inductance_h,
    initial_phase_current_a,
    initial_upper_dc_link_voltage_v,
    initial_lower_dc_link_voltage_v,
    start_time_s,
    stop_time_s,
    fixed_step_s,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        source_resistance_ohm,
        dc_link_capacitance_f,
        load_resistance_ohm,
        load_inductance_h,
        initial_upper_dc_link_voltage_v,
        initial_lower_dc_link_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    current = Float64.(initial_phase_current_a)
    all(isfinite, values) && length(current) == 3 && all(isfinite, current) ||
        throw(ArgumentError("independent NPC inputs must be finite"))
    source_voltage, modulation, frequency, phase, source_resistance, capacitance,
        load_resistance, load_inductance, upper_voltage, lower_voltage,
        start_time, stop_time, step = values
    source_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        source_resistance > 0.0 && capacitance > 0.0 && load_resistance > 0.0 &&
        load_inductance > 0.0 && upper_voltage > 0.0 && lower_voltage > 0.0 &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 ||
        throw(ArgumentError("independent NPC physical domain is invalid"))
    isapprox(upper_voltage + lower_voltage, source_voltage; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent NPC split-link voltage must sum to its source"))
    abs(sum(current)) <= 1.0e-10 * max(maximum(abs, current), 1.0) ||
        throw(ArgumentError("independent NPC three-wire initial currents must sum to zero"))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError("independent NPC horizon must contain integer fixed steps"))
    return (
        source_voltage=source_voltage,
        modulation=modulation,
        frequency=frequency,
        phase=phase,
        source_resistance=source_resistance,
        capacitance=capacitance,
        load_resistance=load_resistance,
        load_inductance=load_inductance,
        initial_state=[current..., upper_voltage, lower_voltage],
        start_time=start_time,
        stop_time=stop_time,
        step=step,
        step_count=step_count,
    )
end

function _independent_npc_reference(parameters, time_s)
    angle = 2.0 * pi * parameters.frequency * time_s + parameters.phase
    return ntuple(phase -> parameters.modulation *
        sin(angle - (phase - 1) * 2.0 * pi / 3.0), 3)
end

struct IndependentAverageThreeLevelNeutralPointClampedTrace
    time_s::Vector{Float64}
    source_current_a::Vector{Float64}
    upper_dc_link_voltage_v::Vector{Float64}
    lower_dc_link_voltage_v::Vector{Float64}
    midpoint_current_a::Vector{Float64}
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    circuit_residual_v::Matrix{Float64}
    energy_residual_w::Vector{Float64}
end

function independent_average_three_level_neutral_point_clamped_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    source_resistance_ohm::Real,
    dc_link_capacitance_f::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    initial_upper_dc_link_voltage_v::Real,
    initial_lower_dc_link_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    parameters = _independent_npc_inputs(
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        source_resistance_ohm,
        dc_link_capacitance_f,
        load_resistance_ohm,
        load_inductance_h,
        initial_phase_current_a,
        initial_upper_dc_link_voltage_v,
        initial_lower_dc_link_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    )
    time = [parameters.start_time + sample * parameters.step
        for sample in 0:parameters.step_count]
    state = Matrix{Float64}(undef, 5, length(time))
    state[:, 1] .= parameters.initial_state
    source_current = Vector{Float64}(undef, length(time))
    upper_voltage = Vector{Float64}(undef, length(time))
    lower_voltage = Vector{Float64}(undef, length(time))
    midpoint_current = Vector{Float64}(undef, length(time))
    phase_voltage = Matrix{Float64}(undef, 3, length(time))
    stored_energy = Vector{Float64}(undef, length(time))
    circuit_residual = zeros(3, length(time))
    energy_residual = zeros(length(time))
    identity5 = Matrix{Float64}(I, 5, 5)
    function level_weights(time_s)
        reference = _independent_npc_reference(parameters, time_s)
        positive = max.(reference, 0.0)
        negative = max.(-collect(reference), 0.0)
        neutral = 1.0 .- abs.(reference)
        return positive, neutral, negative
    end
    function record!(sample)
        positive, neutral, negative = level_weights(time[sample])
        observed = _independent_npc_observables(
            view(state, :, sample),
            positive,
            neutral,
            negative,
            parameters.source_voltage,
            parameters.source_resistance,
            parameters.capacitance,
            parameters.load_inductance,
        )
        source_current[sample] = observed.source_current
        upper_voltage[sample] = state[4, sample]
        lower_voltage[sample] = state[5, sample]
        midpoint_current[sample] = observed.midpoint_current
        phase_voltage[:, sample] .= observed.phase_voltage
        stored_energy[sample] = observed.stored_energy
        return observed
    end
    previous_observed = record!(1)
    for sample in 2:length(time)
        previous_positive, _, previous_negative = level_weights(time[sample - 1])
        endpoint_positive, _, endpoint_negative = level_weights(time[sample])
        previous_matrix, previous_forcing = _independent_npc_state_matrix(
            previous_positive,
            previous_negative,
            parameters.source_voltage,
            parameters.source_resistance,
            parameters.capacitance,
            parameters.load_resistance,
            parameters.load_inductance,
        )
        endpoint_matrix, endpoint_forcing = _independent_npc_state_matrix(
            endpoint_positive,
            endpoint_negative,
            parameters.source_voltage,
            parameters.source_resistance,
            parameters.capacitance,
            parameters.load_resistance,
            parameters.load_inductance,
        )
        previous_state = view(state, :, sample - 1)
        state[:, sample] .= (identity5 - 0.5 * parameters.step * endpoint_matrix) \
            ((identity5 + 0.5 * parameters.step * previous_matrix) * previous_state +
             0.5 * parameters.step * (previous_forcing + endpoint_forcing))
        observed = record!(sample)
        average_current = 0.5 .* (state[1:3, sample - 1] .+ state[1:3, sample])
        average_voltage = 0.5 .* (previous_observed.phase_voltage .+ observed.phase_voltage)
        derivative = (state[1:3, sample] .- state[1:3, sample - 1]) ./ parameters.step
        circuit_residual[:, sample] .= average_voltage .-
            parameters.load_resistance .* average_current .-
            parameters.load_inductance .* derivative
        input_energy = 0.5 * parameters.step * parameters.source_voltage *
            (previous_observed.source_current + observed.source_current)
        load_energy = 0.5 * parameters.step * parameters.load_resistance * (
            sum(abs2, state[1:3, sample - 1]) + sum(abs2, state[1:3, sample])
        )
        source_energy = 0.5 * parameters.step * parameters.source_resistance * (
            previous_observed.source_current^2 + observed.source_current^2
        )
        energy_residual[sample] = (input_energy - load_energy - source_energy -
            (observed.stored_energy - previous_observed.stored_energy)) / parameters.step
        previous_observed = observed
    end
    return IndependentAverageThreeLevelNeutralPointClampedTrace(
        time,
        source_current,
        upper_voltage,
        lower_voltage,
        midpoint_current,
        phase_voltage,
        state[1:3, :],
        stored_energy,
        circuit_residual,
        energy_residual,
    )
end

struct IndependentSwitchingThreeLevelNeutralPointClampedTrace
    time_s::Vector{Float64}
    requested_level::Matrix{Int8}
    requested_gate_state::BitMatrix
    effective_level::Matrix{Int8}
    source_current_a::Vector{Float64}
    upper_dc_link_voltage_v::Vector{Float64}
    lower_dc_link_voltage_v::Vector{Float64}
    midpoint_current_a::Vector{Float64}
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

const IndependentSwitchingThreeLevelTTypeTrace =
    IndependentSwitchingThreeLevelNeutralPointClampedTrace

function independent_switching_three_level_neutral_point_clamped_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    dc_link_capacitance_f::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    initial_upper_dc_link_voltage_v::Real,
    initial_lower_dc_link_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real=0.0,
    leg_topology::Symbol=:neutral_point_clamped,
)
    parameters = _independent_npc_inputs(
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        source_resistance_ohm,
        dc_link_capacitance_f,
        load_resistance_ohm,
        load_inductance_h,
        initial_phase_current_a,
        initial_upper_dc_link_voltage_v,
        initial_lower_dc_link_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    )
    carrier_frequency = Float64(carrier_frequency_hz)
    dead_time = Float64(dead_time_s)
    isfinite(carrier_frequency) && carrier_frequency > parameters.frequency &&
        isfinite(dead_time) && dead_time >= 0.0 || throw(ArgumentError(
            "independent three-level switching carrier and dead time are invalid",
        ))
    leg_topology in (:neutral_point_clamped, :t_type) || throw(ArgumentError(
        "independent three-level switching reference received an unknown leg topology",
    ))
    time = [parameters.start_time + sample * parameters.step
        for sample in 0:parameters.step_count]
    carrier(time_s) = begin
        cycle = mod(carrier_frequency * time_s, 1.0)
        1.0 - abs(2.0 * cycle - 1.0)
    end
    function requested_level_at(phase, time_s)
        reference = _independent_npc_reference(parameters, time_s)[phase]
        carrier_value = carrier(time_s)
        return reference >= carrier_value ? Int8(1) :
            -reference >= carrier_value ? Int8(-1) : Int8(0)
    end
    requested_level = Matrix{Int8}(undef, 3, length(time))
    requested_gate = falses(12, length(time))
    for sample in eachindex(time), phase in 1:3
        level = requested_level_at(phase, time[sample])
        requested_level[phase, sample] = level
        offset = 4 * (phase - 1)
        if level == 1
            requested_gate[offset + 1, sample] = true
            leg_topology === :neutral_point_clamped &&
                (requested_gate[offset + 2, sample] = true)
        elseif level == 0
            requested_gate[(offset + 2):(offset + 3), sample] .= true
        else
            leg_topology === :neutral_point_clamped &&
                (requested_gate[offset + 3, sample] = true)
            requested_gate[offset + 4, sample] = true
        end
    end
    effective_level = Matrix{Int8}(undef, 3, length(time))
    applied_level = Union{Nothing,Int8}[requested_level[phase, 1] for phase in 1:3]
    pending_level = copy(requested_level[:, 1])
    dead_time_endpoint = fill(-Inf, 3)
    effective_level[:, 1] .= requested_level[:, 1]
    state = Matrix{Float64}(undef, 5, length(time))
    state[:, 1] .= parameters.initial_state
    source_current = Vector{Float64}(undef, length(time))
    upper_voltage = Vector{Float64}(undef, length(time))
    lower_voltage = Vector{Float64}(undef, length(time))
    midpoint_current = Vector{Float64}(undef, length(time))
    phase_voltage = Matrix{Float64}(undef, 3, length(time))
    stored_energy = Vector{Float64}(undef, length(time))
    kcl_residual = Vector{Float64}(undef, length(time))
    identity5 = Matrix{Float64}(I, 5, 5)
    function record!(sample)
        positive = Float64.(effective_level[:, sample] .== 1)
        neutral = Float64.(effective_level[:, sample] .== 0)
        negative = Float64.(effective_level[:, sample] .== -1)
        observed = _independent_npc_observables(
            view(state, :, sample),
            positive,
            neutral,
            negative,
            parameters.source_voltage,
            parameters.source_resistance,
            parameters.capacitance,
            parameters.load_inductance,
        )
        source_current[sample] = observed.source_current
        upper_voltage[sample] = state[4, sample]
        lower_voltage[sample] = state[5, sample]
        midpoint_current[sample] = observed.midpoint_current
        phase_voltage[:, sample] .= observed.phase_voltage
        stored_energy[sample] = observed.stored_energy
        kcl_residual[sample] = abs(sum(state[1:3, sample]))
        return nothing
    end
    record!(1)
    for sample in 2:length(time)
        command_changed = false
        for phase in 1:3
            desired = requested_level[phase, sample]
            if desired != requested_level[phase, sample - 1]
                applied_level[phase] = nothing
                pending_level[phase] = desired
                dead_time_endpoint[phase] = time[sample] + dead_time
                command_changed = true
            end
            tolerance = 64.0 * eps(Float64) * max(1.0, abs(time[sample]))
            if applied_level[phase] === nothing &&
                time[sample] >= dead_time_endpoint[phase] - tolerance
                applied_level[phase] = pending_level[phase]
            end
            effective_level[phase, sample] =
                applied_level[phase] === nothing ? Int8(0) : applied_level[phase]
        end
        positive = Float64.(effective_level[:, sample] .== 1)
        negative = Float64.(effective_level[:, sample] .== -1)
        matrix, forcing = _independent_npc_state_matrix(
            positive,
            negative,
            parameters.source_voltage,
            parameters.source_resistance,
            parameters.capacitance,
            parameters.load_resistance,
            parameters.load_inductance,
        )
        topology_changed = command_changed ||
            effective_level[:, sample] != effective_level[:, sample - 1]
        if topology_changed
            half_step = parameters.step / 2.0
            intermediate = (identity5 - half_step * matrix) \
                (state[:, sample - 1] + half_step * forcing)
            state[:, sample] .= (identity5 - half_step * matrix) \
                (intermediate + half_step * forcing)
        else
            state[:, sample] .= (identity5 - 0.5 * parameters.step * matrix) \
                ((identity5 + 0.5 * parameters.step * matrix) * state[:, sample - 1] +
                 parameters.step * forcing)
        end
        state[1:3, sample] .-= sum(state[1:3, sample]) / 3.0
        record!(sample)
    end
    return IndependentSwitchingThreeLevelNeutralPointClampedTrace(
        time,
        requested_level,
        requested_gate,
        effective_level,
        source_current,
        upper_voltage,
        lower_voltage,
        midpoint_current,
        phase_voltage,
        state[1:3, :],
        stored_energy,
        kcl_residual,
    )
end

function independent_switching_three_level_t_type_trace(; kwargs...)
    haskey(kwargs, :leg_topology) && throw(ArgumentError(
        "T-type reference fixes its canonical leg topology",
    ))
    return independent_switching_three_level_neutral_point_clamped_trace(;
        kwargs...,
        leg_topology=:t_type,
    )
end

struct IndependentSwitchingFlyingCapacitorTrace
    time_s::Vector{Float64}
    requested_level::Matrix{Int8}
    requested_gate_state::BitMatrix
    applied_gate_state::BitMatrix
    effective_state::Matrix{Int8}
    source_current_a::Vector{Float64}
    flying_capacitor_voltage_v::Matrix{Float64}
    flying_capacitor_current_a::Matrix{Float64}
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function _independent_flying_capacitor_gate_state(
    normalized_reference,
    capacitor_voltage_error_v,
    phase_current_a,
    time_s,
    carrier_frequency_hz,
    balance_voltage_tolerance_v,
)
    carrier_cycle = mod(carrier_frequency_hz * time_s, 1.0)
    carrier = 1.0 - abs(2.0 * carrier_cycle - 1.0)
    levels = Vector{Int8}(undef, 3)
    gates = falses(12)
    for phase in 1:3
        reference = normalized_reference[phase]
        level = reference >= carrier ? Int8(1) :
            -reference >= carrier ? Int8(-1) : Int8(0)
        levels[phase] = level
        offset = 4 * (phase - 1)
        if level == 1
            gates[(offset + 1):(offset + 2)] .= true
        elseif level == -1
            gates[(offset + 3):(offset + 4)] .= true
        else
            use_upper_capacitor_path =
                abs(capacitor_voltage_error_v[phase]) > balance_voltage_tolerance_v ?
                capacitor_voltage_error_v[phase] * phase_current_a[phase] < 0.0 :
                iseven(floor(Int, 2.0 * carrier_frequency_hz * time_s + phase - 1))
            if use_upper_capacitor_path
                gates[offset + 1] = true
                gates[offset + 3] = true
            else
                gates[offset + 2] = true
                gates[offset + 4] = true
            end
        end
    end
    return levels, gates
end

function _independent_flying_capacitor_mode(applied_gate, phase_current_a)
    applied_gate == Bool[1, 1, 0, 0] && return Int8(2)
    applied_gate == Bool[1, 0, 1, 0] && return Int8(1)
    applied_gate == Bool[0, 1, 0, 1] && return Int8(-1)
    applied_gate == Bool[0, 0, 1, 1] && return Int8(-2)
    return phase_current_a >= 0.0 ? Int8(-2) : Int8(2)
end

function _independent_flying_capacitor_state_matrix(
    mode,
    source_resistance_ohm,
    flying_capacitance_f,
    load_resistance_ohm,
    load_inductance_h,
    input_voltage_v,
)
    source_connection = Float64[value in (1, 2) for value in mode]
    capacitor_voltage_sign = Float64[value == 1 ? -1 : value == -1 ? 1 : 0
        for value in mode]
    capacitor_current_sign = Float64[value == 1 ? 1 : value == -1 ? -1 : 0
        for value in mode]
    projection = Matrix{Float64}(I, 3, 3) .- fill(1.0 / 3.0, 3, 3)
    state_matrix = zeros(6, 6)
    state_matrix[1:3, 1:3] .= (
        -load_resistance_ohm .* Matrix{Float64}(I, 3, 3) .-
        source_resistance_ohm .* projection *
            (source_connection * transpose(source_connection))
    ) ./ load_inductance_h
    state_matrix[1:3, 4:6] .= projection * Diagonal(capacitor_voltage_sign) ./
        load_inductance_h
    state_matrix[4:6, 1:3] .= Diagonal(capacitor_current_sign) ./
        flying_capacitance_f
    forcing = vcat(
        input_voltage_v .* (projection * source_connection) ./ load_inductance_h,
        zeros(3),
    )
    return state_matrix, forcing, source_connection, capacitor_current_sign
end

function independent_switching_flying_capacitor_trace(;
    input_voltage_v::Real,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    flying_capacitance_f::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    initial_flying_capacitor_voltage_v,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real,
    balance_voltage_tolerance_v::Real=1.0e-3,
)
    values = Float64.((
        input_voltage_v,
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        carrier_frequency_hz,
        source_resistance_ohm,
        flying_capacitance_f,
        load_resistance_ohm,
        load_inductance_h,
        start_time_s,
        stop_time_s,
        fixed_step_s,
        dead_time_s,
        balance_voltage_tolerance_v,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent flying-capacitor inputs must be finite",
    ))
    input_voltage, modulation, frequency, phase, carrier_frequency,
        source_resistance, capacitance, load_resistance, load_inductance,
        start_time, stop_time, step, dead_time, balance_tolerance = values
    input_voltage > 0.0 && 0.0 < modulation <= 1.0 && frequency > 0.0 &&
        carrier_frequency > frequency && source_resistance > 0.0 && capacitance > 0.0 &&
        load_resistance > 0.0 && load_inductance > 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 && dead_time >= step ||
        throw(ArgumentError("independent flying-capacitor physical domain is invalid"))
    balance_tolerance >= 0.0 || throw(ArgumentError(
        "independent flying-capacitor balance tolerance must be nonnegative",
    ))
    initial_current = Float64[value for value in initial_phase_current_a]
    initial_voltage = Float64[value for value in initial_flying_capacitor_voltage_v]
    length(initial_current) == 3 && length(initial_voltage) == 3 &&
        all(isfinite, (initial_current..., initial_voltage...)) &&
        all(>(0.0), initial_voltage) || throw(ArgumentError(
        "independent flying-capacitor initial state requires three finite currents and positive voltages",
    ))
    abs(sum(initial_current)) <= 1.0e-10 * max(maximum(abs, initial_current), 1.0) ||
        throw(ArgumentError("independent three-wire initial current must sum to zero"))
    step_count = round(Int, (stop_time - start_time) / step)
    all(value -> isapprox(value, round(value); atol=1.0e-10, rtol=1.0e-10), (
        (stop_time - start_time) / step,
        inv(carrier_frequency * step),
        dead_time / step,
    )) || throw(ArgumentError(
        "independent flying-capacitor horizon, carrier, and dead time must lie on the step calendar",
    ))
    time = [start_time + sample * step for sample in 0:step_count]
    state = Matrix{Float64}(undef, 6, length(time))
    state[:, 1] .= vcat(initial_current, initial_voltage)
    requested_level = Matrix{Int8}(undef, 3, length(time))
    requested_gate = falses(12, length(time))
    applied_gate = falses(12, length(time))
    effective_state = Matrix{Int8}(undef, 3, length(time))
    source_current = Vector{Float64}(undef, length(time))
    capacitor_current = Matrix{Float64}(undef, 3, length(time))
    phase_voltage = Matrix{Float64}(undef, 3, length(time))
    stored_energy = Vector{Float64}(undef, length(time))
    kcl_residual = Vector{Float64}(undef, length(time))
    commanded_gate = falses(12)
    applied = falses(12)
    due_time = fill(Inf, 12)
    identity6 = Matrix{Float64}(I, 6, 6)
    reference_at(time_s) = [modulation * sin(
        2.0 * pi * frequency * time_s + phase - (phase_index - 1) * 2.0 * pi / 3.0,
    ) for phase_index in 1:3]
    function request_at!(sample, current, voltage)
        levels, gates = _independent_flying_capacitor_gate_state(
            reference_at(time[sample]),
            voltage .- 0.5 * input_voltage,
            current,
            time[sample],
            carrier_frequency,
            balance_tolerance,
        )
        requested_level[:, sample] .= levels
        requested_gate[:, sample] .= gates
        return gates
    end
    function observe!(sample, mode, source_connection, capacitor_sign)
        current = view(state, 1:3, sample)
        voltage = view(state, 4:6, sample)
        input_current = dot(source_connection, current)
        dc_positive_voltage = input_voltage - source_resistance * input_current
        capacitor_voltage_sign = Float64[value == 1 ? -1 : value == -1 ? 1 : 0
            for value in mode]
        pole_voltage = source_connection .* dc_positive_voltage .+
            capacitor_voltage_sign .* voltage
        phase_voltage[:, sample] .= pole_voltage .- sum(pole_voltage) / 3.0
        source_current[sample] = input_current
        capacitor_current[:, sample] .= capacitor_sign .* current
        stored_energy[sample] = 0.5 * load_inductance * sum(abs2, current) +
            0.5 * capacitance * sum(abs2, voltage)
        kcl_residual[sample] = abs(sum(current))
        return nothing
    end
    initial_gates = request_at!(1, initial_current, initial_voltage)
    commanded_gate .= initial_gates
    applied .= initial_gates
    applied_gate[:, 1] .= applied
    initial_mode = Int8[_independent_flying_capacitor_mode(
        applied[(4 * (phase_index - 1) + 1):(4 * phase_index)],
        initial_current[phase_index],
    ) for phase_index in 1:3]
    effective_state[:, 1] .= initial_mode
    _, _, initial_source_connection, initial_capacitor_sign =
        _independent_flying_capacitor_state_matrix(
            initial_mode,
            source_resistance,
            capacitance,
            load_resistance,
            load_inductance,
            input_voltage,
        )
    observe!(1, initial_mode, initial_source_connection, initial_capacitor_sign)
    previous_mode = copy(initial_mode)
    for sample in 2:length(time)
        previous_state = view(state, :, sample - 1)
        desired = request_at!(sample, view(previous_state, 1:3), view(previous_state, 4:6))
        command_changed = false
        for index in 1:12
            desired[index] == commanded_gate[index] && continue
            commanded_gate[index] = desired[index]
            command_changed = true
            if desired[index]
                due_time[index] = time[sample] + dead_time
            else
                applied[index] = false
                due_time[index] = Inf
            end
        end
        for index in 1:12
            commanded_gate[index] && !applied[index] &&
                time[sample] >= due_time[index] - 64.0 * eps(max(1.0, abs(time[sample]))) &&
                (applied[index] = true)
        end
        applied_gate[:, sample] .= applied
        mode = Int8[_independent_flying_capacitor_mode(
            applied[(4 * (phase_index - 1) + 1):(4 * phase_index)],
            previous_state[phase_index],
        ) for phase_index in 1:3]
        effective_state[:, sample] .= mode
        state_matrix, forcing, source_connection, capacitor_sign =
            _independent_flying_capacitor_state_matrix(
                mode,
                source_resistance,
                capacitance,
                load_resistance,
                load_inductance,
                input_voltage,
            )
        topology_changed = command_changed || mode != previous_mode
        if topology_changed
            half_step = step / 2.0
            intermediate = (identity6 - half_step * state_matrix) \
                (previous_state + half_step * forcing)
            state[:, sample] .= (identity6 - half_step * state_matrix) \
                (intermediate + half_step * forcing)
        else
            state[:, sample] .= (identity6 - 0.5 * step * state_matrix) \
                ((identity6 + 0.5 * step * state_matrix) * previous_state + step * forcing)
        end
        state[1:3, sample] .-= sum(state[1:3, sample]) / 3.0
        observe!(sample, mode, source_connection, capacitor_sign)
        request_at!(sample, view(state, 1:3, sample), view(state, 4:6, sample))
        requested_gate[:, sample] .= commanded_gate
        previous_mode .= mode
    end
    return IndependentSwitchingFlyingCapacitorTrace(
        time,
        requested_level,
        requested_gate,
        applied_gate,
        effective_state,
        source_current,
        state[4:6, :],
        capacitor_current,
        phase_voltage,
        state[1:3, :],
        stored_energy,
        kcl_residual,
    )
end

struct IndependentSwitchingCascadedHBridgeTrace
    time_s::Vector{Float64}
    requested_level::Matrix{Int8}
    requested_cell_state::Array{Int8,3}
    requested_gate_state::BitMatrix
    applied_gate_state::BitMatrix
    effective_cell_state::Array{Int8,3}
    cell_dc_voltage_v::Array{Float64,3}
    cell_dc_current_a::Array{Float64,3}
    phase_voltage_v::Matrix{Float64}
    phase_current_a::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function _independent_cascaded_h_bridge_cell_command(
    normalized_reference,
    cell_voltage_error_v,
    phase_current_a,
    carrier_cycle,
)
    phase_count, cell_count = size(cell_voltage_error_v)
    state = zeros(Int8, phase_count, cell_count)
    level = zeros(Int8, phase_count)
    for phase in 1:phase_count
        requested = clamp(
            round(Int, cell_count * normalized_reference[phase]),
            -cell_count,
            cell_count,
        )
        level[phase] = requested
        selected_count = abs(requested)
        selected_count == 0 && continue
        polarity = Int8(sign(requested))
        rotation = mod(carrier_cycle + phase - 1, cell_count)
        tie_order = mod.((0:(cell_count - 1)) .- rotation, cell_count)
        discharge = polarity * phase_current_a[phase] > 0.0
        order = sortperm(1:cell_count; by=cell -> (
            discharge ? -cell_voltage_error_v[phase, cell] :
                cell_voltage_error_v[phase, cell],
            tie_order[cell],
        ))
        state[phase, order[1:selected_count]] .= polarity
    end
    return level, state
end

function _independent_cascaded_h_bridge_gates(cell_state, carrier_cycle)
    phase_count, cell_count = size(cell_state)
    gates = falses(4 * phase_count * cell_count)
    for phase in 1:phase_count, cell in 1:cell_count
        first = 4 * ((phase - 1) * cell_count + cell - 1) + 1
        state = cell_state[phase, cell]
        if state == 1
            gates[first] = true
            gates[first + 3] = true
        elseif state == -1
            gates[first + 1] = true
            gates[first + 2] = true
        elseif iseven(carrier_cycle + phase + cell)
            gates[first] = true
            gates[first + 2] = true
        else
            gates[first + 1] = true
            gates[first + 3] = true
        end
    end
    return gates
end

function _independent_cascaded_h_bridge_effective_state(
    applied_gate,
    phase_current_a,
)
    phase_count = length(phase_current_a)
    cell_count = div(length(applied_gate), 4 * phase_count)
    state = zeros(Int8, phase_count, cell_count)
    for phase in 1:phase_count, cell in 1:cell_count
        first = 4 * ((phase - 1) * cell_count + cell - 1) + 1
        gates = applied_gate[first:(first + 3)]
        state[phase, cell] = gates == Bool[1, 0, 0, 1] ? Int8(1) :
            gates == Bool[0, 1, 1, 0] ? Int8(-1) :
            gates in (Bool[1, 0, 1, 0], Bool[0, 1, 0, 1]) ? Int8(0) :
            phase_current_a[phase] > 0.0 ? Int8(-1) :
            phase_current_a[phase] < 0.0 ? Int8(1) : Int8(0)
    end
    return state
end

function _independent_cascaded_h_bridge_state_matrix(
    cell_state,
    capacitance_f,
    load_resistance_ohm,
    load_inductance_h,
)
    phase_count, cell_count = size(cell_state)
    state_count = phase_count + phase_count * cell_count
    matrix = zeros(state_count, state_count)
    projection = Matrix{Float64}(I, phase_count, phase_count) .-
        fill(1.0 / phase_count, phase_count, phase_count)
    cell_voltage_map = zeros(phase_count, phase_count * cell_count)
    for phase in 1:phase_count, cell in 1:cell_count
        cell_index = (phase - 1) * cell_count + cell
        cell_voltage_map[phase, cell_index] = cell_state[phase, cell]
        matrix[phase_count + cell_index, phase] =
            -cell_state[phase, cell] / capacitance_f[phase, cell]
    end
    matrix[1:phase_count, 1:phase_count] .=
        -load_resistance_ohm / load_inductance_h .* Matrix{Float64}(
            I,
            phase_count,
            phase_count,
        )
    matrix[1:phase_count, (phase_count + 1):end] .=
        projection * cell_voltage_map ./ load_inductance_h
    return matrix, projection, cell_voltage_map
end

function independent_switching_cascaded_h_bridge_trace(;
    cell_dc_capacitance_f,
    modulation::Symbol=:nearest_level,
    modulation_index::Real,
    fundamental_frequency_hz::Real,
    phase_rad::Real=0.0,
    carrier_frequency_hz::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    initial_phase_current_a,
    initial_cell_dc_voltage_v,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
    dead_time_s::Real,
)
    initial_voltage = Matrix{Float64}(initial_cell_dc_voltage_v)
    phase_count, cell_count = size(initial_voltage)
    capacitance = if cell_dc_capacitance_f isa Real
        fill(Float64(cell_dc_capacitance_f), phase_count, cell_count)
    else
        Matrix{Float64}(cell_dc_capacitance_f)
    end
    initial_current = Float64[value for value in initial_phase_current_a]
    values = Float64.((
        modulation_index,
        fundamental_frequency_hz,
        phase_rad,
        carrier_frequency_hz,
        load_resistance_ohm,
        load_inductance_h,
        start_time_s,
        stop_time_s,
        fixed_step_s,
        dead_time_s,
    ))
    phase_count == 3 && 2 <= cell_count <= 8 && size(capacitance) == size(initial_voltage) &&
        length(initial_current) == phase_count &&
        all(isfinite, (values..., capacitance..., initial_current..., initial_voltage...)) ||
        throw(ArgumentError(
            "independent cascaded H-bridge inputs require three phases and two through eight finite cells",
        ))
    modulation in (:nearest_level, :phase_shifted_carrier) || throw(ArgumentError(
        "independent cascaded H-bridge modulation must be nearest level or phase-shifted carrier",
    ))
    modulation, frequency, phase, carrier_frequency, resistance, inductance,
        start_time, stop_time, step, dead_time = values
    0.0 < modulation <= 1.0 && frequency > 0.0 &&
        carrier_frequency > frequency && resistance > 0.0 && inductance > 0.0 &&
        all(>(0.0), capacitance) && all(>(0.0), initial_voltage) &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 &&
        dead_time >= step || throw(ArgumentError(
        "independent cascaded H-bridge physical domain is invalid",
    ))
    abs(sum(initial_current)) <=
        1.0e-10 * max(maximum(abs, initial_current), 1.0) || throw(ArgumentError(
        "independent cascaded H-bridge initial phase currents must sum to zero",
    ))
    step_count = round(Int, (stop_time - start_time) / step)
    all(value -> isapprox(value, round(value); atol=1.0e-10, rtol=1.0e-10), (
        (stop_time - start_time) / step,
        inv(carrier_frequency * step),
        dead_time / step,
    )) || throw(ArgumentError(
        "independent cascaded H-bridge horizon, carrier, and dead time must lie on the step calendar",
    ))
    time = [start_time + sample * step for sample in 0:step_count]
    sample_count = length(time)
    valve_count = 4 * phase_count * cell_count
    requested_level = Matrix{Int8}(undef, phase_count, sample_count)
    requested_cell_state = Array{Int8,3}(undef, phase_count, cell_count, sample_count)
    requested_gate = falses(valve_count, sample_count)
    applied_gate = falses(valve_count, sample_count)
    effective_state = Array{Int8,3}(undef, phase_count, cell_count, sample_count)
    cell_voltage = Array{Float64,3}(undef, phase_count, cell_count, sample_count)
    cell_current = Array{Float64,3}(undef, phase_count, cell_count, sample_count)
    phase_voltage = Matrix{Float64}(undef, phase_count, sample_count)
    phase_current = Matrix{Float64}(undef, phase_count, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    initial_cell_voltage = Float64[]
    for phase_index in 1:phase_count, cell in 1:cell_count
        push!(initial_cell_voltage, initial_voltage[phase_index, cell])
    end
    state = vcat(initial_current, initial_cell_voltage)
    identity_matrix = Matrix{Float64}(I, length(state), length(state))
    commanded_gate = falses(valve_count)
    applied = falses(valve_count)
    due_time = fill(Inf, valve_count)
    reference_at(time_s) = [modulation * sin(
        2.0 * pi * frequency * time_s + phase -
            (phase_index - 1) * 2.0 * pi / 3.0,
    ) for phase_index in 1:phase_count]
    function command_at(time_s, current, voltage)
        phase_mean = sum(voltage; dims=2) ./ cell_count
        voltage_error = voltage .- phase_mean
        carrier_cycle = floor(Int,
            carrier_frequency * time_s +
                64.0eps(max(1.0, carrier_frequency * time_s)),
        )
        references = reference_at(time_s)
        level, cells = if modulation === :nearest_level
            _independent_cascaded_h_bridge_cell_command(
                references,
                voltage_error,
                current,
                carrier_cycle,
            )
        else
            phase_shifted_cells = zeros(Int8, phase_count, cell_count)
            for phase_index in 1:phase_count, cell in 1:cell_count
                carrier = independent_converter_triangular_carrier(
                    time_s,
                    carrier_frequency,
                    2.0 * pi * (cell - 1) / cell_count,
                )
                phase_shifted_cells[phase_index, cell] =
                    abs(references[phase_index]) >= carrier ?
                        Int8(sign(references[phase_index])) : Int8(0)
            end
            Int8[sum(view(phase_shifted_cells, phase_index, :))
                for phase_index in 1:phase_count], phase_shifted_cells
        end
        gates = _independent_cascaded_h_bridge_gates(cells, carrier_cycle)
        return level, cells, gates
    end
    function observe!(sample, cells)
        current = view(phase_current, :, sample)
        voltage = view(cell_voltage, :, :, sample)
        pole_voltage = vec(sum(cells .* voltage; dims=2))
        phase_voltage[:, sample] .= pole_voltage .- sum(pole_voltage) / phase_count
        cell_current[:, :, sample] .= -cells .* current
        stored_energy[sample] = 0.5 * inductance * sum(abs2, current) +
            0.5 * sum(capacitance .* voltage .^ 2)
        kcl_residual[sample] = abs(sum(current))
        return nothing
    end
    phase_current[:, 1] .= initial_current
    cell_voltage[:, :, 1] .= initial_voltage
    initial_level, initial_cells, initial_gates = command_at(
        time[1],
        initial_current,
        initial_voltage,
    )
    requested_level[:, 1] .= initial_level
    requested_cell_state[:, :, 1] .= initial_cells
    requested_gate[:, 1] .= initial_gates
    commanded_gate .= initial_gates
    applied .= initial_gates
    applied_gate[:, 1] .= applied
    effective_state[:, :, 1] .= initial_cells
    observe!(1, initial_cells)
    previous_effective = copy(initial_cells)
    for sample in 2:sample_count
        previous_current = view(phase_current, :, sample - 1)
        previous_voltage = view(cell_voltage, :, :, sample - 1)
        level, cells, desired = command_at(
            time[sample],
            previous_current,
            previous_voltage,
        )
        requested_level[:, sample] .= level
        requested_cell_state[:, :, sample] .= cells
        requested_gate[:, sample] .= desired
        command_changed = false
        for valve in 1:valve_count
            desired[valve] == commanded_gate[valve] && continue
            commanded_gate[valve] = desired[valve]
            command_changed = true
            if desired[valve]
                due_time[valve] = time[sample] + dead_time
            else
                applied[valve] = false
                due_time[valve] = Inf
            end
        end
        for valve in 1:valve_count
            commanded_gate[valve] && !applied[valve] &&
                time[sample] >= due_time[valve] -
                    64.0eps(max(1.0, abs(time[sample]))) &&
                (applied[valve] = true)
        end
        applied_gate[:, sample] .= applied
        cells_effective = _independent_cascaded_h_bridge_effective_state(
            applied,
            previous_current,
        )
        effective_state[:, :, sample] .= cells_effective
        matrix, _, _ = _independent_cascaded_h_bridge_state_matrix(
            cells_effective,
            capacitance,
            resistance,
            inductance,
        )
        topology_changed = command_changed || cells_effective != previous_effective
        if topology_changed
            half_step = step / 2.0
            left = identity_matrix - half_step * matrix
            intermediate = left \ state
            state = left \ intermediate
        else
            state = (identity_matrix - 0.5 * step * matrix) \
                ((identity_matrix + 0.5 * step * matrix) * state)
        end
        state[1:phase_count] .-= sum(state[1:phase_count]) / phase_count
        phase_current[:, sample] .= state[1:phase_count]
        for phase_index in 1:phase_count, cell in 1:cell_count
            cell_index = (phase_index - 1) * cell_count + cell
            cell_voltage[phase_index, cell, sample] =
                state[phase_count + cell_index]
        end
        observe!(sample, cells_effective)
        previous_effective .= cells_effective
    end
    return IndependentSwitchingCascadedHBridgeTrace(
        time,
        requested_level,
        requested_cell_state,
        requested_gate,
        applied_gate,
        effective_state,
        cell_voltage,
        cell_current,
        phase_voltage,
        phase_current,
        stored_energy,
        kcl_residual,
    )
end

struct IndependentSwitchingInterleavedChopperTrace
    time_s::Vector{Float64}
    gate_state::BitMatrix
    channel_switch_voltage_v::Matrix{Float64}
    channel_inductor_current_a::Matrix{Float64}
    input_current_a::Vector{Float64}
    output_voltage_v::Vector{Float64}
    load_current_a::Vector{Float64}
    stored_energy_j::Vector{Float64}
    kcl_residual_a::Vector{Float64}
end

function independent_switching_interleaved_chopper_trace(;
    input_voltage_v::Real,
    duty::Real,
    carrier_frequency_hz::Real,
    source_resistance_ohm::Real,
    inductor_resistance_ohm,
    inductance_h,
    capacitance_f::Real,
    load_resistance_ohm::Real,
    initial_channel_inductor_current_a,
    initial_output_voltage_v::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    resistances = Float64.(inductor_resistance_ohm)
    inductances = Float64.(inductance_h)
    initial_currents = Float64.(initial_channel_inductor_current_a)
    count = length(inductances)
    2 <= count <= 8 && length(resistances) == count &&
        length(initial_currents) == count || throw(DimensionMismatch(
            "independent interleaved chopper requires two through eight equally described channels",
        ))
    values = Float64.((
        input_voltage_v,
        duty,
        carrier_frequency_hz,
        source_resistance_ohm,
        capacitance_f,
        load_resistance_ohm,
        initial_output_voltage_v,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, (values..., resistances..., inductances..., initial_currents...)) ||
        throw(ArgumentError("independent interleaved chopper inputs must be finite"))
    input_voltage, modulation_duty, carrier_frequency, source_resistance,
        capacitance, load_resistance, initial_voltage, start_time, stop_time, step =
        values
    input_voltage > 0.0 && 0.0 < modulation_duty < 1.0 &&
        carrier_frequency > 0.0 && source_resistance > 0.0 && capacitance > 0.0 &&
        load_resistance > 0.0 && initial_voltage >= 0.0 && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 && all(>=(0.0), resistances) &&
        all(>(0.0), inductances) && all(>=(0.0), initial_currents) ||
        throw(ArgumentError("independent interleaved chopper domain is invalid"))
    step_count = (stop_time - start_time) / step
    isapprox(step_count, round(step_count); atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent interleaved horizon must contain integer fixed steps",
        ))
    sample_count = round(Int, step_count) + 1
    time = collect(range(start_time, stop_time; length=sample_count))
    phases = [2.0 * pi * (channel - 1) / count for channel in 1:count]
    carrier(time_s, phase) = begin
        cycle = mod(carrier_frequency * time_s + phase / (2.0 * pi), 1.0)
        cycle <= 0.5 ? 2.0 * cycle : 2.0 * (1.0 - cycle)
    end
    gate_state = BitMatrix(undef, count, sample_count)
    for sample in eachindex(time), channel in 1:count
        gate_state[channel, sample] =
            modulation_duty >= carrier(time[sample], phases[channel])
    end
    switch_voltage = Matrix{Float64}(undef, count, sample_count)
    channel_current = Matrix{Float64}(undef, count, sample_count)
    input_current = Vector{Float64}(undef, sample_count)
    output_voltage = Vector{Float64}(undef, sample_count)
    load_current = Vector{Float64}(undef, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    kcl_residual = Vector{Float64}(undef, sample_count)
    state = vcat(initial_currents, initial_voltage)
    channel_current[:, 1] = initial_currents
    output_voltage[1] = initial_voltage
    function system(gates)
        matrix = zeros(count + 1, count + 1)
        source = zeros(count + 1)
        for channel in 1:count
            matrix[channel, channel] -= resistances[channel] / inductances[channel]
            matrix[channel, end] = -1.0 / inductances[channel]
            if gates[channel]
                for source_channel in 1:count
                    gates[source_channel] || continue
                    matrix[channel, source_channel] -=
                        source_resistance / inductances[channel]
                end
                source[channel] = input_voltage / inductances[channel]
            end
            matrix[end, channel] = 1.0 / capacitance
        end
        matrix[end, end] = -1.0 / (load_resistance * capacitance)
        return matrix, source
    end
    identity_matrix = Matrix{Float64}(I, count + 1, count + 1)
    function trapezoidal(candidate_state, gates)
        matrix, source = system(gates)
        return (identity_matrix - 0.5 * step * matrix) \
            ((identity_matrix + 0.5 * step * matrix) * candidate_state + step * source)
    end
    function backward_euler_half_steps(candidate_state, gates)
        matrix, source = system(gates)
        half_step = step / 2.0
        left = identity_matrix - half_step * matrix
        first = left \ (candidate_state + half_step * source)
        return left \ (first + half_step * source)
    end
    function record_sample!(sample)
        currents = view(channel_current, :, sample)
        gates = view(gate_state, :, sample)
        input_current[sample] = sum(currents[gates])
        input_node_voltage = input_voltage - source_resistance * input_current[sample]
        for channel in 1:count
            switch_voltage[channel, sample] = gates[channel] ? input_node_voltage : 0.0
        end
        load_current[sample] = output_voltage[sample] / load_resistance
        capacitor_current = sum(currents) - load_current[sample]
        kcl_residual[sample] =
            sum(currents) - load_current[sample] - capacitor_current
        stored_energy[sample] = 0.5 * capacitance * output_voltage[sample]^2 +
            sum(0.5 * inductances[channel] * currents[channel]^2
                for channel in 1:count)
    end
    record_sample!(1)
    for sample in 2:sample_count
        gates = view(gate_state, :, sample)
        topology_changed = gates != view(gate_state, :, sample - 1)
        state = topology_changed ? backward_euler_half_steps(state, gates) :
            trapezoidal(state, gates)
        channel_current[:, sample] = view(state, 1:count)
        output_voltage[sample] = state[end]
        minimum(view(channel_current, :, sample)) >= 0.0 || throw(DomainError(
            minimum(view(channel_current, :, sample)),
            "independent interleaved chopper left continuous conduction",
        ))
        record_sample!(sample)
    end
    return IndependentSwitchingInterleavedChopperTrace(
        time,
        gate_state,
        switch_voltage,
        channel_current,
        input_current,
        output_voltage,
        load_current,
        stored_energy,
        kcl_residual,
    )
end
