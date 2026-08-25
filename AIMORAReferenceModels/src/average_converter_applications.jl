struct IndependentAverageConverterApplicationTrace
    application::Symbol
    time_s::Vector{Float64}
    state::Matrix{Float64}
    input_voltage_v::Matrix{Float64}
    input_current_a::Matrix{Float64}
    output_voltage_v::Matrix{Float64}
    output_current_a::Matrix{Float64}
    dc_link_voltage_v::Matrix{Float64}
    stored_energy_j::Vector{Float64}
    energy_residual_w::Vector{Float64}
    operating_mode::Vector{Symbol}
    load_delivery_state::BitVector
    bypass_synchronized_state::BitVector
end

function _reference_application_phase(peak, frequency, time_s; shift=0.0)
    angle = 2.0 * pi * frequency * time_s + shift
    return [peak * sin(angle - (phase - 1) * 2.0 * pi / 3.0) for phase in 1:3]
end

function _reference_application_phase_rate(peak, frequency, time_s; shift=0.0)
    angle = 2.0 * pi * frequency * time_s + shift
    angular_frequency = 2.0 * pi * frequency
    return [angular_frequency * peak * cos(
        angle - (phase - 1) * 2.0 * pi / 3.0,
    ) for phase in 1:3]
end

function _reference_application_limit(values, maximum_phase_voltage)
    projected = values .- sum(values) / 3.0
    magnitude = maximum(abs, projected; init=0.0)
    magnitude <= maximum_phase_voltage && return projected
    return projected .* (maximum_phase_voltage / magnitude)
end

function _reference_application_input_control(
    source_voltage,
    current,
    dc_voltage,
    requested_power,
    parameters,
)
    target_power = requested_power + parameters.dc_gain *
        (parameters.dc_reference - dc_voltage)
    target_current = target_power .* source_voltage ./ sum(abs2, source_voltage)
    target_rate = parameters.current_bandwidth .* (target_current .- current)
    requested_terminal_voltage = source_voltage .- parameters.input_resistance .* current .-
        parameters.input_inductance .* target_rate
    terminal_voltage = _reference_application_limit(
        requested_terminal_voltage,
        0.5 * parameters.modulation_limit * dc_voltage,
    )
    current_rate = (source_voltage .- terminal_voltage .-
        parameters.input_resistance .* current) ./ parameters.input_inductance
    return (; current_rate, terminal_voltage, target_current)
end

function _reference_shunt_active_filter_mode(time_s, p, event_side)
    passed(event_time) = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        event_time,
        p.fixed_step,
        event_side,
    )
    passed(p.reference_restore) && return :restored_operation
    passed(p.reference_loss) && return :reference_loss_operation
    return :normal_operation
end

function _reference_shunt_active_filter(
    time_s,
    state,
    p;
    event_side::Symbol=:right,
)
    current = state[1:3]
    dc_voltage = state[4]
    integral = state[5:7]
    grid_voltage = _reference_application_phase(p.grid_peak, p.grid_frequency, time_s)
    fundamental = _reference_application_phase(
        p.load_fundamental_peak,
        p.grid_frequency,
        time_s;
        shift=-p.load_phase_shift,
    )
    fifth = _reference_application_phase(
        p.load_fifth_peak,
        5.0 * p.grid_frequency,
        time_s;
        shift=p.load_phase_shift,
    )
    seventh = _reference_application_phase(
        p.load_seventh_peak,
        7.0 * p.grid_frequency,
        time_s;
        shift=-p.load_phase_shift,
    )
    load_current = fundamental .+ fifth .+ seventh
    active_source = _reference_application_phase(
        p.load_fundamental_peak * cos(p.load_phase_shift),
        p.grid_frequency,
        time_s,
    )
    operating_mode = _reference_shunt_active_filter_mode(time_s, p, event_side)
    compensation_available = operating_mode !== :reference_loss_operation
    base_reference = compensation_available ? load_current .- active_source : zeros(3)
    available_base_rate = _reference_application_phase_rate(
        p.load_fundamental_peak,
        p.grid_frequency,
        time_s;
        shift=-p.load_phase_shift,
    ) .+ _reference_application_phase_rate(
        p.load_fifth_peak,
        5.0 * p.grid_frequency,
        time_s;
        shift=p.load_phase_shift,
    ) .+ _reference_application_phase_rate(
        p.load_seventh_peak,
        7.0 * p.grid_frequency,
        time_s;
        shift=-p.load_phase_shift,
    ) .- _reference_application_phase_rate(
        p.load_fundamental_peak * cos(p.load_phase_shift),
        p.grid_frequency,
        time_s,
    )
    base_rate = compensation_available ? available_base_rate : zeros(3)
    charging_amplitude = p.dc_gain * (p.dc_reference - dc_voltage)
    reference = base_reference .- charging_amplitude .*
        _reference_application_phase(1.0, p.grid_frequency, time_s)
    reference_rate = base_rate .- charging_amplitude .*
        _reference_application_phase_rate(1.0, p.grid_frequency, time_s)
    error = reference .- current
    bridge_voltage = _reference_application_limit(
        grid_voltage .+ p.filter_resistance .* current .+
            p.filter_inductance .* reference_rate .+ p.current_gain .* error .+
            p.integral_gain .* integral,
        0.5 * p.modulation_limit * dc_voltage,
    )
    current_rate = (bridge_voltage .- grid_voltage .-
        p.filter_resistance .* current) ./ p.filter_inductance
    bridge_power = dot(bridge_voltage, current)
    dc_rate = -bridge_power / (p.dc_capacitance * dc_voltage)
    stored = 0.5 * p.filter_inductance * sum(abs2, current) +
        0.5 * p.dc_capacitance * dc_voltage^2
    loss = p.filter_resistance * sum(abs2, current)
    return (
        derivative=[current_rate..., dc_rate, error...],
        input_voltage=grid_voltage,
        input_current=-current,
        output_voltage=grid_voltage,
        output_current=load_current .- current,
        dc_links=[dc_voltage, 0.0],
        stored,
        input_power=-dot(grid_voltage, current),
        loss,
        operating_mode,
        load_delivery=true,
        bypass_synchronized=false,
    )
end

function _reference_dynamic_voltage_restorer(time_s, state, p; event_side::Symbol=:right)
    current = state[1:3]
    dc_voltage = state[4]
    event_side in (:left, :right) || throw(ArgumentError(
        "independent converter-application event side must be :left or :right",
    ))
    same_boundary(event_time_s) = isapprox(
        time_s,
        event_time_s;
        atol=16.0 * eps(Float64) * max(abs(event_time_s), eps(Float64)),
        rtol=0.0,
    )
    at_start = same_boundary(p.sag_start)
    at_stop = same_boundary(p.sag_stop)
    sag_active = if at_start
        event_side === :right
    elseif at_stop
        event_side === :left
    else
        p.sag_start < time_s < p.sag_stop
    end
    sag_multiplier = sag_active ? p.sag_retained : 1.0
    passed(event_time) = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        event_time,
        p.fixed_step,
        event_side,
    )
    operating_mode = passed(p.sag_stop) ? :restored_operation :
        passed(p.bypass_stop) ? :voltage_injection_operation :
        passed(p.bypass_start) ? :bypass_operation :
        passed(p.sag_start) ? :voltage_injection_operation : :normal_operation
    source_voltage = _reference_application_phase(
        sag_multiplier * p.source_peak,
        p.source_frequency,
        time_s,
    )
    target_voltage = _reference_application_phase(
        p.target_peak,
        p.source_frequency,
        time_s,
    )
    requested_injection = _reference_application_limit(
        p.injection_gain .* (target_voltage .- source_voltage),
        0.5 * p.transformer_ratio * p.modulation_limit * dc_voltage,
    )
    injection = operating_mode === :bypass_operation ? zeros(3) : requested_injection
    load_voltage = source_voltage .+ injection
    current_rate = (load_voltage .- p.load_resistance .* current) ./ p.load_inductance
    injection_power = dot(injection, current)
    dc_rate = -injection_power / (p.dc_capacitance * dc_voltage)
    stored = 0.5 * p.load_inductance * sum(abs2, current) +
        0.5 * p.dc_capacitance * dc_voltage^2
    loss = p.load_resistance * sum(abs2, current)
    delivered_voltage_pu = sqrt(sum(abs2, load_voltage) / (1.5 * p.target_peak^2))
    return (
        derivative=[current_rate..., dc_rate],
        input_voltage=source_voltage,
        input_current=current,
        output_voltage=load_voltage,
        output_current=current,
        dc_links=[dc_voltage, 0.0],
        stored,
        input_power=dot(source_voltage, current),
        loss,
        operating_mode,
        load_delivery=delivered_voltage_pu >= 0.9,
        bypass_synchronized=false,
    )
end

function _reference_uninterruptible_power_supply_boundary_passed(
    time_s,
    event_time_s,
    fixed_step_s,
    event_side,
)
    same_boundary = isapprox(
        time_s,
        event_time_s;
        atol=16.0 * eps(Float64) * max(abs(event_time_s), fixed_step_s),
        rtol=0.0,
    )
    same_boundary && return event_side === :right
    return time_s > event_time_s
end

function _reference_uninterruptible_power_supply_synchronization(p)
    phase_error = rem2pi(
        p.bypass_shift + 2.0 * pi *
            (p.bypass_frequency - p.output_frequency) * p.bypass_transfer,
        RoundNearest,
    )
    voltage_mismatch = abs(p.bypass_peak - p.output_peak) / p.output_peak
    frequency_mismatch = abs(p.bypass_frequency - p.output_frequency)
    accepted = voltage_mismatch <= p.maximum_bypass_voltage_mismatch &&
        frequency_mismatch <= p.maximum_bypass_frequency_mismatch &&
        abs(phase_error) <= p.maximum_bypass_phase_mismatch
    return (; accepted, voltage_mismatch, frequency_mismatch, phase_error)
end

function _reference_uninterruptible_power_supply_mode(time_s, p, event_side)
    passed(event_time) = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        event_time,
        p.fixed_step,
        event_side,
    )
    passed(p.double_conversion_restore) && return :restored_double_conversion
    passed(p.bypass_transfer) &&
        _reference_uninterruptible_power_supply_synchronization(p).accepted &&
        return :synchronized_bypass
    passed(p.source_loss) && return :stored_energy_support
    return :normal_double_conversion
end

function _reference_uninterruptible_power_supply(
    time_s,
    state,
    p;
    event_side::Symbol=:right,
)
    input_current = state[1:3]
    dc_voltage = state[4]
    output_current = state[5:7]
    mode = _reference_uninterruptible_power_supply_mode(time_s, p, event_side)
    loss_has_passed = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        p.source_loss,
        p.fixed_step,
        event_side,
    )
    recovery_has_passed = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        p.source_recovery,
        p.fixed_step,
        event_side,
    )
    source_available = !loss_has_passed || recovery_has_passed
    source_voltage = source_available ? _reference_application_phase(
        p.source_peak,
        p.source_frequency,
        time_s,
    ) : zeros(3)
    requested_output = _reference_application_phase(p.output_peak, p.output_frequency, time_s)
    inverter_voltage = _reference_application_limit(
        requested_output,
        0.5 * p.modulation_limit * dc_voltage,
    )
    synchronization = _reference_uninterruptible_power_supply_synchronization(p)
    bypass_voltage = _reference_application_phase(
        p.bypass_peak,
        p.bypass_frequency,
        time_s;
        shift=p.bypass_shift,
    )
    bypass_active = mode === :synchronized_bypass
    output_voltage = bypass_active ? bypass_voltage : inverter_voltage
    output_rate = (output_voltage .- p.load_resistance .* output_current) ./
        p.load_inductance
    inverter_power = bypass_active ? 0.0 : dot(output_voltage, output_current)
    input_control = if source_available
        _reference_application_input_control(
            source_voltage,
            input_current,
            dc_voltage,
            max(inverter_power, 0.0),
            p,
        )
    else
        current_rate = -p.input_resistance .* input_current ./ p.input_inductance
        (; current_rate, terminal_voltage=zeros(3), target_current=zeros(3))
    end
    rectifier_power = source_available ?
        dot(input_control.terminal_voltage, input_current) : 0.0
    dc_rate = (rectifier_power - inverter_power) / (p.dc_capacitance * dc_voltage)
    stored = 0.5 * p.input_inductance * sum(abs2, input_current) +
        0.5 * p.dc_capacitance * dc_voltage^2 +
        0.5 * p.load_inductance * sum(abs2, output_current)
    loss = p.input_resistance * sum(abs2, input_current) +
        p.load_resistance * sum(abs2, output_current)
    bypass_power = bypass_active ? dot(bypass_voltage, output_current) : 0.0
    delivered_voltage_pu = sqrt(sum(abs2, output_voltage) / (1.5 * p.output_peak^2))
    return (
        derivative=[input_control.current_rate..., dc_rate, output_rate...],
        input_voltage=source_voltage,
        input_current,
        output_voltage,
        output_current,
        dc_links=[dc_voltage, 0.0],
        stored,
        input_power=dot(source_voltage, input_current) + bypass_power,
        loss,
        operating_mode=mode,
        load_delivery=delivered_voltage_pu >= p.minimum_load_delivery_voltage,
        bypass_synchronized=synchronization.accepted,
    )
end

function _reference_conductive_charger_mode(time_s, p, event_side)
    passed(event_time) = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        event_time,
        p.fixed_step,
        event_side,
    )
    passed(p.output_short_clear) && return :restored_operation
    passed(p.output_short_start) && return :output_terminal_short_circuit
    passed(p.load_step) && return :load_step_operation
    return :normal_operation
end

function _reference_conductive_charger(
    time_s,
    state,
    p;
    event_side::Symbol=:right,
)
    input_current = state[1:3]
    dc_voltage = state[4]
    inductor_current = state[5]
    output_voltage = max(state[6], 0.0)
    mode = _reference_conductive_charger_mode(time_s, p, event_side)
    load_resistance = mode === :output_terminal_short_circuit ?
        p.output_short_resistance :
        mode in (:load_step_operation, :restored_operation) ?
            p.stepped_output_load_resistance : p.output_load_resistance
    source_voltage = _reference_application_phase(p.source_peak, p.source_frequency, time_s)
    load_power = output_voltage^2 / load_resistance
    input_control = _reference_application_input_control(
        source_voltage,
        input_current,
        dc_voltage,
        load_power,
        p,
    )
    rectifier_power = dot(input_control.terminal_voltage, input_current)
    duty = clamp((output_voltage + p.output_gain *
        (p.output_reference - output_voltage)) / dc_voltage, 0.0, p.modulation_limit)
    switch_voltage = duty * dc_voltage
    inductor_rate = (switch_voltage - output_voltage) / p.output_inductance
    capacitor_rate = (inductor_current - output_voltage / load_resistance) /
        p.output_capacitance
    chopper_power = switch_voltage * inductor_current
    dc_rate = (rectifier_power - chopper_power) / (p.dc_capacitance * dc_voltage)
    stored = 0.5 * p.input_inductance * sum(abs2, input_current) +
        0.5 * p.dc_capacitance * dc_voltage^2 +
        0.5 * p.output_inductance * inductor_current^2 +
        0.5 * p.output_capacitance * output_voltage^2
    loss = p.input_resistance * sum(abs2, input_current) + load_power
    return (
        derivative=[input_control.current_rate..., dc_rate, inductor_rate, capacitor_rate],
        input_voltage=source_voltage,
        input_current,
        output_voltage=[output_voltage, 0.0, 0.0],
        output_current=[output_voltage / load_resistance, 0.0, 0.0],
        dc_links=[dc_voltage, 0.0],
        stored,
        input_power=dot(source_voltage, input_current),
        loss,
        operating_mode=mode,
        load_delivery=mode !== :output_terminal_short_circuit &&
            output_voltage >= 0.9 * p.output_reference,
        bypass_synchronized=false,
    )
end

function _reference_solid_state_transformer_mode(time_s, p, event_side)
    passed(event_time) = _reference_uninterruptible_power_supply_boundary_passed(
        time_s,
        event_time,
        p.fixed_step,
        event_side,
    )
    passed(p.transformer_fault_clear) && return :restored_operation
    passed(p.transformer_fault_start) && return :transformer_side_fault_operation
    return :normal_operation
end

function _reference_solid_state_transformer(
    time_s,
    state,
    p;
    event_side::Symbol=:right,
)
    input_current = state[1:3]
    primary_voltage = state[4]
    transformer_current = state[5]
    secondary_voltage = state[6]
    output_current = state[7:9]
    source_voltage = _reference_application_phase(p.source_peak, p.source_frequency, time_s)
    requested_output = _reference_application_phase(p.output_peak, p.output_frequency, time_s)
    output_voltage = _reference_application_limit(
        requested_output,
        0.5 * p.modulation_limit * secondary_voltage,
    )
    output_rate = (output_voltage .- p.load_resistance .* output_current) ./
        p.load_inductance
    inverter_power = dot(output_voltage, output_current)
    operating_mode = _reference_solid_state_transformer_mode(time_s, p, event_side)
    transformer_fault_current = operating_mode === :transformer_side_fault_operation ?
        secondary_voltage / p.transformer_fault_resistance : 0.0
    transformer_fault_power = secondary_voltage * transformer_fault_current
    transformer_drive = clamp(
        secondary_voltage + p.secondary_gain * (p.secondary_reference - secondary_voltage),
        0.0,
        p.modulation_limit * p.transformer_ratio * primary_voltage,
    )
    transformer_rate = (transformer_drive - secondary_voltage -
        p.transformer_resistance * transformer_current) / p.transformer_inductance
    transformer_input_power = transformer_drive * transformer_current
    transformer_output_power = secondary_voltage * transformer_current
    input_control = _reference_application_input_control(
        source_voltage,
        input_current,
        primary_voltage,
        max(transformer_input_power, inverter_power, 0.0),
        p,
    )
    rectifier_power = dot(input_control.terminal_voltage, input_current)
    primary_rate = (rectifier_power - transformer_input_power) /
        (p.primary_capacitance * primary_voltage)
    secondary_rate = (transformer_output_power - inverter_power -
        transformer_fault_power) /
        (p.secondary_capacitance * secondary_voltage)
    stored = 0.5 * p.input_inductance * sum(abs2, input_current) +
        0.5 * p.primary_capacitance * primary_voltage^2 +
        0.5 * p.transformer_inductance * transformer_current^2 +
        0.5 * p.secondary_capacitance * secondary_voltage^2 +
        0.5 * p.load_inductance * sum(abs2, output_current)
    loss = p.input_resistance * sum(abs2, input_current) +
        p.transformer_resistance * transformer_current^2 +
        p.load_resistance * sum(abs2, output_current) + transformer_fault_power
    return (
        derivative=[input_control.current_rate..., primary_rate, transformer_rate,
            secondary_rate, output_rate...],
        input_voltage=source_voltage,
        input_current,
        output_voltage,
        output_current,
        dc_links=[primary_voltage, secondary_voltage],
        stored,
        input_power=dot(source_voltage, input_current),
        loss,
        operating_mode,
        load_delivery=sqrt(sum(abs2, output_voltage) / (1.5 * p.output_peak^2)) >= 0.9,
        bypass_synchronized=false,
    )
end

function _reference_application_observation(
    application,
    time_s,
    state,
    parameters;
    event_side::Symbol=:right,
)
    application === :shunt_active_filter &&
        return _reference_shunt_active_filter(
            time_s,
            state,
            parameters;
            event_side,
        )
    application === :dynamic_voltage_restorer &&
        return _reference_dynamic_voltage_restorer(
            time_s,
            state,
            parameters;
            event_side,
        )
    application === :uninterruptible_power_supply &&
        return _reference_uninterruptible_power_supply(
            time_s,
            state,
            parameters;
            event_side,
        )
    application === :conductive_electric_vehicle_charger &&
        return _reference_conductive_charger(
            time_s,
            state,
            parameters;
            event_side,
        )
    application === :solid_state_transformer &&
        return _reference_solid_state_transformer(
            time_s,
            state,
            parameters;
            event_side,
        )
    throw(ArgumentError("independent converter application is unknown"))
end

function independent_average_converter_application_trace(;
    application::Symbol,
    parameters::NamedTuple,
    initial_state,
    start_time_s=0.0,
    stop_time_s,
    fixed_step_s,
    reference_substeps=4,
)
    start_time, stop_time, step = Float64.((start_time_s, stop_time_s, fixed_step_s))
    isfinite(start_time) && isfinite(stop_time) && isfinite(step) && start_time >= 0.0 &&
        stop_time > start_time && step > 0.0 || throw(ArgumentError(
            "independent converter-application horizon is invalid",
        ))
    substeps = Int(reference_substeps)
    substeps >= 1 || throw(ArgumentError(
        "independent converter-application substep count must be positive",
    ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent converter-application horizon must contain integer steps",
        ))
    state_value = collect(Float64.(initial_state))
    all(isfinite, state_value) || throw(ArgumentError(
        "independent converter-application initial state must be finite",
    ))
    sample_count = step_count + 1
    time = [start_time + (sample - 1) * step for sample in 1:sample_count]
    state_trace = Matrix{Float64}(undef, length(state_value), sample_count)
    input_voltage = Matrix{Float64}(undef, 3, sample_count)
    input_current = Matrix{Float64}(undef, 3, sample_count)
    output_voltage = Matrix{Float64}(undef, 3, sample_count)
    output_current = Matrix{Float64}(undef, 3, sample_count)
    dc_links = zeros(2, sample_count)
    stored_energy = Vector{Float64}(undef, sample_count)
    residual = zeros(sample_count)
    operating_mode = fill(:normal_operation, sample_count)
    load_delivery = trues(sample_count)
    bypass_synchronized = falses(sample_count)
    function record!(sample, observation)
        state_trace[:, sample] .= state_value
        input_voltage[:, sample] .= observation.input_voltage
        input_current[:, sample] .= observation.input_current
        output_voltage[:, sample] .= observation.output_voltage
        output_current[:, sample] .= observation.output_current
        dc_links[:, sample] .= observation.dc_links
        stored_energy[sample] = observation.stored
        operating_mode[sample] = hasproperty(observation, :operating_mode) ?
            observation.operating_mode : :normal_operation
        load_delivery[sample] = hasproperty(observation, :load_delivery) ?
            observation.load_delivery : true
        bypass_synchronized[sample] = hasproperty(observation, :bypass_synchronized) ?
            observation.bypass_synchronized : false
    end
    observation = _reference_application_observation(
        application,
        start_time,
        state_value,
        parameters,
    )
    record!(1, observation)
    substep = step / substeps
    for sample in 2:sample_count
        initial_energy = observation.stored
        energy_input = 0.0
        energy_loss = 0.0
        local_time = time[sample - 1]
        for _ in 1:substeps
            initial = _reference_application_observation(
                application,
                local_time,
                state_value,
                parameters,
            )
            predicted = state_value .+ substep .* initial.derivative
            endpoint_time = local_time + substep
            endpoint = _reference_application_observation(
                application,
                endpoint_time,
                predicted,
                parameters,
                event_side=:left,
            )
            state_value .+= 0.5 * substep .* (initial.derivative .+ endpoint.derivative)
            energy_input += 0.5 * substep * (initial.input_power + endpoint.input_power)
            energy_loss += 0.5 * substep * (initial.loss + endpoint.loss)
            local_time += substep
        end
        observation = _reference_application_observation(
            application,
            time[sample],
            state_value,
            parameters,
        )
        residual[sample] = energy_input - energy_loss -
            (observation.stored - initial_energy)
        record!(sample, observation)
    end
    return IndependentAverageConverterApplicationTrace(
        application,
        time,
        state_trace,
        input_voltage,
        input_current,
        output_voltage,
        output_current,
        dc_links,
        stored_energy,
        residual ./ step,
        operating_mode,
        load_delivery,
        bypass_synchronized,
    )
end
