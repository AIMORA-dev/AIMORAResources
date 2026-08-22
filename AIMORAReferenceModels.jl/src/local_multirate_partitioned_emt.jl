export IndependentPassiveLadderResult,
       IndependentExponentialHistorySubcycleResult,
       IndependentLaggedRLCResult,
       IndependentPartitionedRLCResult,
       IndependentSwitchedPassiveLinkResult,
       independent_exact_passive_ladder,
       independent_exact_passive_rlc,
       independent_exact_switched_passive_link,
       independent_exponential_history_subcycle,
       independent_lagged_passive_rlc,
       independent_partitioned_passive_rlc

"""Independent exact trace for a source-fed series-RL and shunt-RC ladder."""
struct IndependentPassiveLadderResult
    time_s::Vector{Float64}
    series_current_a::Matrix{Float64}
    shunt_voltage_v::Matrix{Float64}
    nodal_kcl_residual_a::Matrix{Float64}
    source_power_w::Vector{Float64}
    resistive_loss_w::Vector{Float64}
    storage_rate_w::Vector{Float64}
    power_balance_residual_w::Vector{Float64}
end

"""Independent piecewise-exact trace for one passive link whose parallel switched branch opens once."""
struct IndependentSwitchedPassiveLinkResult
    time_s::Vector{Float64}
    source_current_a::Vector{Float64}
    first_node_voltage_v::Vector{Float64}
    second_node_voltage_v::Vector{Float64}
    link_current_a::Vector{Float64}
    nodal_kcl_residual_a::Matrix{Float64}
    power_balance_residual_w::Vector{Float64}
end

function _independent_switched_link_dynamics(
    source_voltage_v,
    source_resistance_ohm,
    source_inductance_h,
    first_shunt_resistance_ohm,
    first_shunt_capacitance_f,
    second_shunt_resistance_ohm,
    second_shunt_capacitance_f,
    link_conductance_s,
)
    dynamics = [
        -source_resistance_ohm / source_inductance_h -inv(source_inductance_h) 0.0
        inv(first_shunt_capacitance_f) -(inv(first_shunt_resistance_ohm) + link_conductance_s) / first_shunt_capacitance_f link_conductance_s / first_shunt_capacitance_f
        0.0 link_conductance_s / second_shunt_capacitance_f -(link_conductance_s + inv(second_shunt_resistance_ohm)) / second_shunt_capacitance_f
    ]
    return dynamics, [source_voltage_v / source_inductance_h, 0.0, 0.0]
end

"""
Evaluate a source-RL, two-node shunt-RC network with a resistive link and one
parallel switched resistive branch that opens at an exact declared instant.
The two continuous node voltages and source current are propagated by
independent matrix exponentials on each side of the topology change.
"""
function independent_exact_switched_passive_link(;
    start_time_s::Real,
    stop_time_s::Real,
    output_step_s::Real,
    switch_open_time_s::Real,
    source_voltage_v::Real,
    source_resistance_ohm::Real,
    source_inductance_h::Real,
    first_shunt_resistance_ohm::Real,
    first_shunt_capacitance_f::Real,
    second_shunt_resistance_ohm::Real,
    second_shunt_capacitance_f::Real,
    link_resistance_ohm::Real,
    switch_closed_conductance_s::Real,
    switch_open_conductance_s::Real = 0.0,
    initial_source_current_a::Real = 0.0,
    initial_first_node_voltage_v::Real = 0.0,
    initial_second_node_voltage_v::Real = 0.0,
)
    start_time, stop_time, output_step, open_time = Float64.(tuple(
        start_time_s,
        stop_time_s,
        output_step_s,
        switch_open_time_s,
    ))
    source_voltage, source_resistance, source_inductance,
        first_shunt_resistance, first_shunt_capacitance,
        second_shunt_resistance, second_shunt_capacitance,
        link_resistance, closed_switch_conductance,
        open_switch_conductance, initial_current, initial_first_voltage,
        initial_second_voltage = Float64.(tuple(
            source_voltage_v,
            source_resistance_ohm,
            source_inductance_h,
            first_shunt_resistance_ohm,
            first_shunt_capacitance_f,
            second_shunt_resistance_ohm,
            second_shunt_capacitance_f,
            link_resistance_ohm,
            switch_closed_conductance_s,
            switch_open_conductance_s,
            initial_source_current_a,
            initial_first_node_voltage_v,
            initial_second_node_voltage_v,
        ))
    all(isfinite, (
        start_time,
        stop_time,
        output_step,
        open_time,
        source_voltage,
        source_resistance,
        source_inductance,
        first_shunt_resistance,
        first_shunt_capacitance,
        second_shunt_resistance,
        second_shunt_capacitance,
        link_resistance,
        closed_switch_conductance,
        open_switch_conductance,
        initial_current,
        initial_first_voltage,
        initial_second_voltage,
    )) || throw(ArgumentError(
        "independent switched passive-link inputs must be finite",
    ))
    start_time < open_time < stop_time && output_step > 0.0 || throw(
        ArgumentError(
            "independent switched passive-link calendar must contain one interior opening",
        ),
    )
    source_resistance >= 0.0 && source_inductance > 0.0 &&
        first_shunt_resistance > 0.0 && first_shunt_capacitance > 0.0 &&
        second_shunt_resistance > 0.0 && second_shunt_capacitance > 0.0 &&
        link_resistance > 0.0 && closed_switch_conductance >= 0.0 &&
        open_switch_conductance >= 0.0 || throw(ArgumentError(
            "independent switched passive-link elements must be passive with positive storage",
        ))
    interval_ratio = (stop_time - start_time) / output_step
    interval_count = round(Int, interval_ratio)
    abs(interval_ratio - interval_count) <=
        32eps(max(abs(interval_ratio), 1.0)) || throw(ArgumentError(
            "independent switched passive-link horizon must divide by its output step",
        ))
    event_ratio = (open_time - start_time) / output_step
    event_index = round(Int, event_ratio)
    abs(event_ratio - event_index) <= 32eps(max(abs(event_ratio), 1.0)) ||
        throw(ArgumentError(
            "independent switched passive-link opening must align with an output sample",
        ))
    closed_link_conductance = inv(link_resistance) +
        closed_switch_conductance
    open_link_conductance = inv(link_resistance) + open_switch_conductance
    closed_dynamics, forcing = _independent_switched_link_dynamics(
        source_voltage,
        source_resistance,
        source_inductance,
        first_shunt_resistance,
        first_shunt_capacitance,
        second_shunt_resistance,
        second_shunt_capacitance,
        closed_link_conductance,
    )
    open_dynamics, _ = _independent_switched_link_dynamics(
        source_voltage,
        source_resistance,
        source_inductance,
        first_shunt_resistance,
        first_shunt_capacitance,
        second_shunt_resistance,
        second_shunt_capacitance,
        open_link_conductance,
    )
    initial_state = [initial_current, initial_first_voltage, initial_second_voltage]
    closed_equilibrium = -(closed_dynamics \ forcing)
    event_state = closed_equilibrium +
        exp(closed_dynamics * (open_time - start_time)) *
        (initial_state - closed_equilibrium)
    open_equilibrium = -(open_dynamics \ forcing)
    times = start_time .+ collect(0:interval_count) .* output_step
    source_current = Vector{Float64}(undef, length(times))
    first_voltage = similar(source_current)
    second_voltage = similar(source_current)
    link_current = similar(source_current)
    kcl_residual = Matrix{Float64}(undef, 2, length(times))
    power_balance_residual = similar(source_current)
    for sample_index in eachindex(times)
        time_s = times[sample_index]
        before_or_at_opening = time_s <= open_time
        dynamics = before_or_at_opening ? closed_dynamics : open_dynamics
        link_conductance = before_or_at_opening ?
            closed_link_conductance : open_link_conductance
        state = if before_or_at_opening
            closed_equilibrium + exp(closed_dynamics * (time_s - start_time)) *
                (initial_state - closed_equilibrium)
        else
            open_equilibrium + exp(open_dynamics * (time_s - open_time)) *
                (event_state - open_equilibrium)
        end
        derivative = dynamics * state + forcing
        current, voltage_1, voltage_2 = state
        link_current_value = link_conductance * (voltage_1 - voltage_2)
        source_current[sample_index] = current
        first_voltage[sample_index] = voltage_1
        second_voltage[sample_index] = voltage_2
        link_current[sample_index] = link_current_value
        kcl_residual[1, sample_index] = current - link_current_value -
            voltage_1 / first_shunt_resistance -
            first_shunt_capacitance * derivative[2]
        kcl_residual[2, sample_index] = link_current_value -
            voltage_2 / second_shunt_resistance -
            second_shunt_capacitance * derivative[3]
        source_power = source_voltage * current
        resistive_loss = source_resistance * current^2 +
            voltage_1^2 / first_shunt_resistance +
            voltage_2^2 / second_shunt_resistance +
            link_conductance * (voltage_1 - voltage_2)^2
        storage_rate = source_inductance * current * derivative[1] +
            first_shunt_capacitance * voltage_1 * derivative[2] +
            second_shunt_capacitance * voltage_2 * derivative[3]
        power_balance_residual[sample_index] =
            source_power - resistive_loss - storage_rate
    end
    return IndependentSwitchedPassiveLinkResult(
        times,
        source_current,
        first_voltage,
        second_voltage,
        link_current,
        kcl_residual,
        power_balance_residual,
    )
end

function _independent_passive_ladder_parameters(
    source_voltage_v,
    series_resistance_ohm,
    series_inductance_h,
    shunt_resistance_ohm,
    shunt_capacitance_f,
    initial_series_current_a,
    initial_shunt_voltage_v,
)
    source_voltage = Float64(source_voltage_v)
    series_resistance = Float64[series_resistance_ohm...]
    series_inductance = Float64[series_inductance_h...]
    shunt_resistance = Float64[shunt_resistance_ohm...]
    shunt_capacitance = Float64[shunt_capacitance_f...]
    initial_current = Float64[initial_series_current_a...]
    initial_voltage = Float64[initial_shunt_voltage_v...]
    state_count = length(series_resistance)
    state_count > 0 || throw(ArgumentError(
        "independent passive ladder requires at least one section",
    ))
    all(length(values) == state_count for values in (
        series_inductance,
        shunt_resistance,
        shunt_capacitance,
        initial_current,
        initial_voltage,
    )) || throw(DimensionMismatch(
        "independent passive ladder parameter vectors must have equal lengths",
    ))
    all(isfinite, vcat(
        [source_voltage],
        series_resistance,
        series_inductance,
        shunt_resistance,
        shunt_capacitance,
        initial_current,
        initial_voltage,
    )) || throw(ArgumentError(
        "independent passive ladder parameters and initial state must be finite",
    ))
    all(>=(0.0), series_resistance) &&
        all(>(0.0), series_inductance) &&
        all(>(0.0), shunt_resistance) &&
        all(>(0.0), shunt_capacitance) || throw(ArgumentError(
            "independent passive ladder requires passive resistors and positive storage",
        ))
    return (
        source_voltage,
        series_resistance,
        series_inductance,
        shunt_resistance,
        shunt_capacitance,
        initial_current,
        initial_voltage,
    )
end

"""
Evaluate a source-fed series-RL and shunt-RC ladder by a dense matrix
exponential. Section `j` carries current from node `j-1` to node `j`; node
zero is the ideal source and every node `j` owns one resistor and capacitor
to ground. This formulation shares no production stamp, timestep, regional
exchange, rollback, or history implementation.
"""
function independent_exact_passive_ladder(;
    start_time_s::Real,
    stop_time_s::Real,
    output_step_s::Real,
    source_voltage_v::Real,
    series_resistance_ohm,
    series_inductance_h,
    shunt_resistance_ohm,
    shunt_capacitance_f,
    initial_series_current_a = zeros(length(series_resistance_ohm)),
    initial_shunt_voltage_v = zeros(length(series_resistance_ohm)),
)
    start_time, stop_time, output_step = Float64.(tuple(
        start_time_s,
        stop_time_s,
        output_step_s,
    ))
    all(isfinite, (start_time, stop_time, output_step)) &&
        start_time < stop_time && output_step > 0.0 || throw(ArgumentError(
            "independent passive ladder requires a finite forward calendar",
        ))
    ratio = (stop_time - start_time) / output_step
    output_interval_count = round(Int, ratio)
    abs(ratio - output_interval_count) <= 32eps(max(abs(ratio), 1.0)) ||
        throw(ArgumentError(
            "independent passive ladder horizon must divide by its output step",
        ))
    source_voltage, series_resistance, series_inductance,
        shunt_resistance, shunt_capacitance, initial_current,
        initial_voltage = _independent_passive_ladder_parameters(
            source_voltage_v,
            series_resistance_ohm,
            series_inductance_h,
            shunt_resistance_ohm,
            shunt_capacitance_f,
            initial_series_current_a,
            initial_shunt_voltage_v,
        )
    section_count = length(series_resistance)
    dynamics = zeros(Float64, 2section_count, 2section_count)
    forcing = zeros(Float64, 2section_count)
    for section_index in 1:section_count
        current_index = section_index
        voltage_index = section_count + section_index
        dynamics[current_index, current_index] =
            -series_resistance[section_index] / series_inductance[section_index]
        dynamics[current_index, voltage_index] =
            -inv(series_inductance[section_index])
        if section_index == 1
            forcing[current_index] =
                source_voltage / series_inductance[section_index]
        else
            dynamics[current_index, voltage_index - 1] =
                inv(series_inductance[section_index])
        end
        dynamics[voltage_index, current_index] =
            inv(shunt_capacitance[section_index])
        if section_index < section_count
            dynamics[voltage_index, current_index + 1] =
                -inv(shunt_capacitance[section_index])
        end
        dynamics[voltage_index, voltage_index] =
            -inv(
                shunt_resistance[section_index] *
                shunt_capacitance[section_index],
            )
    end
    equilibrium = -(dynamics \ forcing)
    initial_state = vcat(initial_current, initial_voltage)
    times = start_time .+ collect(0:output_interval_count) .* output_step
    series_current = Matrix{Float64}(undef, section_count, length(times))
    shunt_voltage = similar(series_current)
    nodal_kcl_residual = similar(series_current)
    source_power = Vector{Float64}(undef, length(times))
    resistive_loss = similar(source_power)
    storage_rate = similar(source_power)
    power_balance_residual = similar(source_power)
    for sample_index in eachindex(times)
        elapsed = times[sample_index] - start_time
        state = equilibrium +
            exp(dynamics * elapsed) * (initial_state - equilibrium)
        derivative = dynamics * state + forcing
        current = @view(state[1:section_count])
        voltage = @view(state[(section_count + 1):end])
        current_derivative = @view(derivative[1:section_count])
        voltage_derivative = @view(derivative[(section_count + 1):end])
        series_current[:, sample_index] .= current
        shunt_voltage[:, sample_index] .= voltage
        for node_index in 1:section_count
            outgoing_current = node_index < section_count ?
                current[node_index + 1] : 0.0
            nodal_kcl_residual[node_index, sample_index] =
                current[node_index] - outgoing_current -
                voltage[node_index] / shunt_resistance[node_index] -
                shunt_capacitance[node_index] * voltage_derivative[node_index]
        end
        source_power[sample_index] = source_voltage * current[1]
        resistive_loss[sample_index] =
            sum(series_resistance .* current .^ 2) +
            sum(voltage .^ 2 ./ shunt_resistance)
        storage_rate[sample_index] =
            sum(series_inductance .* current .* current_derivative) +
            sum(shunt_capacitance .* voltage .* voltage_derivative)
        power_balance_residual[sample_index] =
            source_power[sample_index] - resistive_loss[sample_index] -
            storage_rate[sample_index]
    end
    return IndependentPassiveLadderResult(
        times,
        series_current,
        shunt_voltage,
        nodal_kcl_residual,
        source_power,
        resistive_loss,
        storage_rate,
        power_balance_residual,
    )
end

"""Independent passive two-region trace with regional exchange diagnostics."""
struct IndependentPartitionedRLCResult
    time_s::Vector{Float64}
    source_current_a::Vector{Float64}
    interface_voltage_v::Vector{Float64}
    voltage_residual_v::Vector{Float64}
    kcl_residual_a::Vector{Float64}
    interface_energy_defect_j::Vector{Float64}
    fixed_point_iterations::Vector{Int}
end

function _independent_passive_values(;
    source_voltage_v,
    source_resistance_ohm,
    source_inductance_h,
    load_resistance_ohm,
    load_capacitance_f,
    initial_source_current_a,
    initial_interface_voltage_v,
)
    values = Float64.(tuple(
        source_voltage_v,
        source_resistance_ohm,
        source_inductance_h,
        load_resistance_ohm,
        load_capacitance_f,
        initial_source_current_a,
        initial_interface_voltage_v,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent passive RLC values must be finite",
    ))
    values[2] >= 0.0 && values[3] > 0.0 && values[4] > 0.0 &&
        values[5] > 0.0 || throw(ArgumentError(
            "independent passive RLC elements require nonnegative resistance and positive storage",
        ))
    return values
end

"""Evaluate the constant-source coupled RLC equations from their matrix exponential without production integration code."""
function independent_exact_passive_rlc(;
    start_time_s::Real,
    stop_time_s::Real,
    output_step_s::Real,
    source_voltage_v::Real,
    source_resistance_ohm::Real,
    source_inductance_h::Real,
    load_resistance_ohm::Real,
    load_capacitance_f::Real,
    initial_source_current_a::Real = 0.0,
    initial_interface_voltage_v::Real = 0.0,
)
    start_time, stop_time, output_step = Float64.(tuple(
        start_time_s,
        stop_time_s,
        output_step_s,
    ))
    all(isfinite, (start_time, stop_time, output_step)) &&
        start_time < stop_time && output_step > 0.0 || throw(ArgumentError(
            "independent exact RLC reference requires a finite forward calendar",
        ))
    ratio = (stop_time - start_time) / output_step
    window_count = round(Int, ratio)
    abs(ratio - window_count) <= 32eps(max(abs(ratio), 1.0)) || throw(
        ArgumentError("independent exact RLC horizon must divide by its output step"),
    )
    voltage_source, source_resistance, source_inductance,
        load_resistance, load_capacitance, initial_current,
        initial_voltage = _independent_passive_values(
            source_voltage_v = source_voltage_v,
            source_resistance_ohm = source_resistance_ohm,
            source_inductance_h = source_inductance_h,
            load_resistance_ohm = load_resistance_ohm,
            load_capacitance_f = load_capacitance_f,
            initial_source_current_a = initial_source_current_a,
            initial_interface_voltage_v = initial_interface_voltage_v,
        )
    dynamics = [
        -source_resistance / source_inductance -inv(source_inductance)
        inv(load_capacitance) -inv(load_resistance * load_capacitance)
    ]
    forcing = [voltage_source / source_inductance, 0.0]
    equilibrium = -(dynamics \ forcing)
    initial = [initial_current, initial_voltage]
    times = start_time .+ collect(0:window_count) .* output_step
    currents = Vector{Float64}(undef, length(times))
    voltages = Vector{Float64}(undef, length(times))
    for index in eachindex(times)
        elapsed = times[index] - start_time
        state = equilibrium + exp(dynamics * elapsed) * (initial - equilibrium)
        currents[index] = state[1]
        voltages[index] = state[2]
    end
    return (
        time_s = times,
        source_current_a = currents,
        interface_voltage_v = voltages,
    )
end

function _independent_linear_sample(times, values, time_s)
    time_s <= first(times) && return first(values)
    time_s >= last(times) && return last(values)
    right = searchsortedfirst(times, time_s)
    times[right] == time_s && return values[right]
    left = right - 1
    weight = (time_s - times[left]) / (times[right] - times[left])
    return (1.0 - weight) * values[left] + weight * values[right]
end

function _independent_midpoint_source_waveform(
    initial_current,
    voltage_time,
    voltage_waveform,
    source_steps,
    communication_step,
    source_voltage,
    source_resistance,
    source_inductance,
)
    time = collect(range(0.0, communication_step; length=source_steps + 1))
    current = Vector{Float64}(undef, source_steps + 1)
    voltage = Vector{Float64}(undef, source_steps + 1)
    current[1] = initial_current
    step = communication_step / source_steps
    for index in eachindex(time)
        voltage[index] = _independent_linear_sample(
            voltage_time,
            voltage_waveform,
            time[index],
        )
    end
    for index in 1:source_steps
        midpoint_forcing = source_voltage -
            0.5 * (voltage[index] + voltage[index + 1])
        current[index + 1] = (
            (source_inductance / step - 0.5source_resistance) * current[index] +
            midpoint_forcing
        ) / (source_inductance / step + 0.5source_resistance)
    end
    return time, current, voltage
end

function _independent_midpoint_load_waveform(
    initial_voltage,
    current_time,
    current_waveform,
    load_steps,
    communication_step,
    load_resistance,
    load_capacitance,
)
    time = collect(range(0.0, communication_step; length=load_steps + 1))
    current = [_independent_linear_sample(current_time, current_waveform, instant)
        for instant in time]
    voltage = Vector{Float64}(undef, load_steps + 1)
    voltage[1] = initial_voltage
    step = communication_step / load_steps
    conductance = inv(load_resistance)
    for index in 1:load_steps
        midpoint_current = 0.5 * (current[index] + current[index + 1])
        voltage[index + 1] = (
            (load_capacitance / step - 0.5conductance) * voltage[index] +
            midpoint_current
        ) / (load_capacitance / step + 0.5conductance)
    end
    return time, current, voltage
end

function _independent_waveform_energy(time, voltage, current)
    energy = 0.0
    for index in 1:(length(time) - 1)
        step = time[index + 1] - time[index]
        energy += step * 0.5 * (voltage[index] + voltage[index + 1]) *
            0.5 * (current[index] + current[index + 1])
    end
    return energy
end

"""Independently execute deterministic linear waveform relaxation on exact integer-related regional calendars."""
function independent_partitioned_passive_rlc(;
    start_time_s::Real,
    stop_time_s::Real,
    communication_step_s::Real,
    source_steps_per_window::Integer,
    load_steps_per_window::Integer,
    source_voltage_v::Real,
    source_resistance_ohm::Real,
    source_inductance_h::Real,
    load_resistance_ohm::Real,
    load_capacitance_f::Real,
    initial_source_current_a::Real = 0.0,
    initial_interface_voltage_v::Real = 0.0,
    voltage_absolute_v::Real = 1.0e-8,
    voltage_relative::Real = 1.0e-7,
    maximum_iterations::Integer = 32,
    relaxation::Real = 1.0,
)
    start_time, stop_time, communication_step = Float64.(tuple(
        start_time_s,
        stop_time_s,
        communication_step_s,
    ))
    ratio = (stop_time - start_time) / communication_step
    window_count = round(Int, ratio)
    isfinite(ratio) && window_count > 0 &&
        abs(ratio - window_count) <= 32eps(max(abs(ratio), 1.0)) || throw(
            ArgumentError("independent partition calendar is not commensurate"),
        )
    source_steps = Int(source_steps_per_window)
    load_steps = Int(load_steps_per_window)
    source_steps > 0 && load_steps > 0 || throw(ArgumentError(
        "independent regional step counts must be positive",
    ))
    voltage_source, source_resistance, source_inductance,
        load_resistance, load_capacitance, initial_current,
        initial_voltage = _independent_passive_values(
            source_voltage_v = source_voltage_v,
            source_resistance_ohm = source_resistance_ohm,
            source_inductance_h = source_inductance_h,
            load_resistance_ohm = load_resistance_ohm,
            load_capacitance_f = load_capacitance_f,
            initial_source_current_a = initial_source_current_a,
            initial_interface_voltage_v = initial_interface_voltage_v,
        )
    absolute_tolerance = Float64(voltage_absolute_v)
    relative_tolerance = Float64(voltage_relative)
    iteration_limit = Int(maximum_iterations)
    damping = Float64(relaxation)
    all(isfinite, (absolute_tolerance, relative_tolerance, damping)) &&
        absolute_tolerance > 0.0 && relative_tolerance >= 0.0 &&
        0.0 < damping <= 1.0 && iteration_limit > 0 || throw(ArgumentError(
            "independent partition iteration policy is invalid",
        ))
    times = start_time .+ collect(0:window_count) .* communication_step
    currents = Float64[initial_current]
    voltages = Float64[initial_voltage]
    voltage_residuals = Float64[]
    kcl_residuals = Float64[]
    energy_defects = Float64[]
    iterations = Int[]
    previous_voltage_slope = 0.0
    conductance = inv(load_resistance)
    for _ in 1:window_count
        load_time = collect(range(0.0, communication_step; length=load_steps + 1))
        voltage_guess = last(voltages) .+ previous_voltage_slope .* load_time
        voltage_guess[1] = last(voltages)
        converged = false
        for iteration in 1:iteration_limit
            source_time, source_current, source_voltage =
                _independent_midpoint_source_waveform(
                    last(currents),
                    load_time,
                    voltage_guess,
                    source_steps,
                    communication_step,
                    voltage_source,
                    source_resistance,
                    source_inductance,
                )
            new_load_time, load_current, load_voltage =
                _independent_midpoint_load_waveform(
                    last(voltages),
                    source_time,
                    source_current,
                    load_steps,
                    communication_step,
                    load_resistance,
                    load_capacitance,
                )
            scale = absolute_tolerance .+ relative_tolerance .* max.(
                abs.(voltage_guess),
                abs.(load_voltage),
            )
            scaled_residual = maximum(abs.(load_voltage .- voltage_guess) ./ scale)
            if scaled_residual <= 1.0
                voltage_residual = maximum(abs.(load_voltage .- voltage_guess))
                endpoint_current = last(source_current)
                capacitor_current = endpoint_current - conductance * last(load_voltage)
                kcl_residual = endpoint_current -
                    (conductance * last(load_voltage) + capacitor_current)
                source_energy = _independent_waveform_energy(
                    source_time,
                    source_voltage,
                    source_current,
                )
                load_energy = _independent_waveform_energy(
                    new_load_time,
                    load_voltage,
                    load_current,
                )
                push!(currents, endpoint_current)
                push!(voltages, last(load_voltage))
                push!(voltage_residuals, voltage_residual)
                push!(kcl_residuals, kcl_residual)
                push!(energy_defects, source_energy - load_energy)
                push!(iterations, iteration)
                previous_voltage_slope =
                    (voltages[end] - voltages[end - 1]) / communication_step
                converged = true
                break
            end
            voltage_guess .= voltage_guess .+ damping .* (load_voltage .- voltage_guess)
            voltage_guess[1] = last(voltages)
        end
        converged || error("independent partition waveform iteration did not converge")
    end
    return IndependentPartitionedRLCResult(
        times,
        currents,
        voltages,
        voltage_residuals,
        kcl_residuals,
        energy_defects,
        iterations,
    )
end

"""Independent exact exponential-history trace under one linearly reconstructed network interval."""
struct IndependentExponentialHistorySubcycleResult
    time_s::Vector{Float64}
    input::Vector{ComplexF64}
    state::Vector{ComplexF64}
    endpoint_history::ComplexF64
    endpoint_gain::ComplexF64
    exact_endpoint_state::ComplexF64
    endpoint_identity_error::Float64
end

function _independent_exponential_history_step(
    previous_state::ComplexF64,
    previous_input::ComplexF64,
    current_input::ComplexF64,
    pole::ComplexF64,
    residue::ComplexF64,
    step_s::Float64,
)
    scaled_pole = pole * step_s
    decay = exp(-scaled_pole)
    linear_average = -expm1(-scaled_pole) / scaled_pole
    current_gain = residue * (1.0 - linear_average)
    previous_gain = residue * (linear_average - decay)
    return decay * previous_state +
        current_gain * current_input +
        previous_gain * previous_input
end

function _independent_exponential_history_trace(
    pole::ComplexF64,
    residue::ComplexF64,
    network_step_s::Float64,
    local_substeps::Int,
    previous_state::ComplexF64,
    previous_input::ComplexF64,
    endpoint_input::ComplexF64,
)
    local_step_s = network_step_s / local_substeps
    time = collect(0:local_substeps) .* local_step_s
    input = ComplexF64[
        previous_input +
        (endpoint_input - previous_input) * (index / local_substeps)
        for index in 0:local_substeps
    ]
    state = Vector{ComplexF64}(undef, local_substeps + 1)
    state[1] = previous_state
    for index in 1:local_substeps
        state[index + 1] = _independent_exponential_history_step(
            state[index],
            input[index],
            input[index + 1],
            pole,
            residue,
            local_step_s,
        )
    end
    return time, input, state
end

"""
Advance `x' = -p*x + p*r*u(t)` over one network interval using exact
exponential convolution on each local substep. The input is the causal linear
reconstruction between the accepted previous endpoint and the proposed
network endpoint. The returned affine endpoint map is independently obtained
from zero and unit endpoint probes and is compared with the one-interval
closed form.
"""
function independent_exponential_history_subcycle(;
    pole_per_s,
    residue,
    network_step_s::Real,
    local_substeps::Integer,
    previous_state=0.0,
    previous_input=0.0,
    endpoint_input=0.0,
)
    pole = ComplexF64(pole_per_s)
    response_residue = ComplexF64(residue)
    network_step = Float64(network_step_s)
    substeps = Int(local_substeps)
    initial_state = ComplexF64(previous_state)
    initial_input = ComplexF64(previous_input)
    final_input = ComplexF64(endpoint_input)
    all(isfinite, (
        real(pole),
        imag(pole),
        real(response_residue),
        imag(response_residue),
        network_step,
        real(initial_state),
        imag(initial_state),
        real(initial_input),
        imag(initial_input),
        real(final_input),
        imag(final_input),
    )) || throw(ArgumentError(
        "independent exponential-history inputs must be finite",
    ))
    real(pole) > 0.0 && network_step > 0.0 && substeps >= 2 || throw(
        ArgumentError(
            "independent exponential history requires a stable pole, positive network step, and at least two local substeps",
        ),
    )
    time, input, state = _independent_exponential_history_trace(
        pole,
        response_residue,
        network_step,
        substeps,
        initial_state,
        initial_input,
        final_input,
    )
    _, _, zero_endpoint_state = _independent_exponential_history_trace(
        pole,
        response_residue,
        network_step,
        substeps,
        initial_state,
        initial_input,
        0.0 + 0.0im,
    )
    _, _, unit_endpoint_state = _independent_exponential_history_trace(
        pole,
        response_residue,
        network_step,
        substeps,
        initial_state,
        initial_input,
        1.0 + 0.0im,
    )
    endpoint_history = last(zero_endpoint_state)
    endpoint_gain = last(unit_endpoint_state) - endpoint_history
    exact_endpoint = _independent_exponential_history_step(
        initial_state,
        initial_input,
        final_input,
        pole,
        response_residue,
        network_step,
    )
    identity_error = abs(
        last(state) - (endpoint_history + endpoint_gain * final_input),
    )
    return IndependentExponentialHistorySubcycleResult(
        time,
        input,
        state,
        endpoint_history,
        endpoint_gain,
        exact_endpoint,
        identity_error,
    )
end

"""Independent one-pass zero-order causal current exchange for a split series-RL/shunt-RC network."""
struct IndependentLaggedRLCResult
    time_s::Vector{Float64}
    interface_current_a::Vector{Float64}
    positive_terminal_voltage_v::Vector{Float64}
    negative_terminal_voltage_v::Vector{Float64}
    voltage_residual_v::Vector{Float64}
    communication_error_estimate_v::Vector{Float64}
    interface_value_age_s::Vector{Float64}
    communication_accepted::Vector{Bool}
end

"""
Independently execute a one-pass causal interface exchange. Each window holds
the current accepted at its starting communication point. Regional endpoint
voltages use independently written trapezoidal series-RL and shunt-RC
companions; only after both endpoints are known is the next-window current
formed from the oriented voltage residual and declared wave impedance.
"""
function independent_lagged_passive_rlc(;
    start_time_s::Real,
    stop_time_s::Real,
    communication_step_s::Real,
    source_amplitude_v::Real,
    source_frequency_hz::Real,
    source_phase_rad::Real=0.0,
    source_offset_v::Real=0.0,
    source_resistance_ohm::Real,
    source_inductance_h::Real,
    load_resistance_ohm::Real,
    load_capacitance_f::Real,
    reference_impedance_ohm::Real,
    relaxation::Real=1.0,
    voltage_base_v::Real=1.0,
    communication_error_absolute_v::Real=1.0e-8,
    communication_error_relative::Real=0.0,
    initial_interface_current_a::Real=0.0,
    initial_positive_voltage_v::Real=0.0,
    initial_negative_voltage_v::Real=0.0,
    initial_load_capacitor_current_a::Real=0.0,
)
    start_time, stop_time, communication_step, source_amplitude,
        source_frequency, source_phase, source_offset, source_resistance,
        source_inductance, load_resistance, load_capacitance,
        reference_impedance, damping, voltage_base, error_absolute,
        error_relative, initial_current, initial_positive_voltage,
        initial_negative_voltage, initial_capacitor_current = Float64.(tuple(
            start_time_s,
            stop_time_s,
            communication_step_s,
            source_amplitude_v,
            source_frequency_hz,
            source_phase_rad,
            source_offset_v,
            source_resistance_ohm,
            source_inductance_h,
            load_resistance_ohm,
            load_capacitance_f,
            reference_impedance_ohm,
            relaxation,
            voltage_base_v,
            communication_error_absolute_v,
            communication_error_relative,
            initial_interface_current_a,
            initial_positive_voltage_v,
            initial_negative_voltage_v,
            initial_load_capacitor_current_a,
        ))
    values = (
        start_time,
        stop_time,
        communication_step,
        source_amplitude,
        source_frequency,
        source_phase,
        source_offset,
        source_resistance,
        source_inductance,
        load_resistance,
        load_capacitance,
        reference_impedance,
        damping,
        voltage_base,
        error_absolute,
        error_relative,
        initial_current,
        initial_positive_voltage,
        initial_negative_voltage,
        initial_capacitor_current,
    )
    all(isfinite, values) || throw(ArgumentError(
        "independent lagged RLC inputs must be finite",
    ))
    start_time < stop_time && communication_step > 0.0 || throw(
        ArgumentError("independent lagged RLC calendar must advance"),
    )
    source_frequency >= 0.0 && source_resistance >= 0.0 &&
        source_inductance > 0.0 && load_resistance > 0.0 &&
        load_capacitance > 0.0 && reference_impedance > 0.0 &&
        0.0 < damping <= 1.0 && voltage_base > 0.0 &&
        error_absolute > 0.0 && error_relative >= 0.0 || throw(
        ArgumentError("independent lagged RLC physical and numerical values are invalid"),
    )
    ratio = (stop_time - start_time) / communication_step
    window_count = round(Int, ratio)
    abs(ratio - window_count) <= 32eps(max(abs(ratio), 1.0)) || throw(
        ArgumentError("independent lagged RLC horizon is not commensurate"),
    )
    source_voltage(time_s) = source_offset + source_amplitude *
        sin(2.0 * pi * source_frequency * time_s + source_phase)
    time = start_time .+ collect(0:window_count) .* communication_step
    interface_current = Vector{Float64}(undef, window_count + 1)
    positive_voltage = similar(interface_current)
    negative_voltage = similar(interface_current)
    voltage_residual = Vector{Float64}(undef, window_count)
    communication_error = similar(voltage_residual)
    value_age = fill(communication_step, window_count)
    accepted = Vector{Bool}(undef, window_count)
    interface_current[1] = initial_current
    positive_voltage[1] = initial_positive_voltage
    negative_voltage[1] = initial_negative_voltage
    source_branch_current = initial_current
    source_branch_voltage = source_voltage(start_time) - initial_positive_voltage
    load_capacitor_current = initial_capacitor_current
    source_companion_resistance = source_resistance +
        2.0 * source_inductance / communication_step
    source_history_coefficient =
        2.0 * source_inductance / communication_step - source_resistance
    load_companion_conductance = 2.0 * load_capacitance / communication_step
    load_resistance_conductance = inv(load_resistance)
    for window_index in 1:window_count
        held_current = interface_current[window_index]
        source_history_current = (
            source_history_coefficient * source_branch_current +
            source_branch_voltage
        ) / source_companion_resistance
        next_source_branch_voltage = source_companion_resistance *
            (held_current - source_history_current)
        next_positive_voltage = source_voltage(time[window_index + 1]) -
            next_source_branch_voltage
        load_history_current =
            -load_companion_conductance * negative_voltage[window_index] -
            load_capacitor_current
        next_negative_voltage = (held_current - load_history_current) /
            (load_resistance_conductance + load_companion_conductance)
        next_load_capacitor_current =
            load_companion_conductance * next_negative_voltage +
            load_history_current
        residual = next_positive_voltage - next_negative_voltage
        error = abs(residual)
        limit = error_absolute + error_relative * max(
            voltage_base,
            abs(next_positive_voltage),
            abs(next_negative_voltage),
        )
        positive_voltage[window_index + 1] = next_positive_voltage
        negative_voltage[window_index + 1] = next_negative_voltage
        voltage_residual[window_index] = residual
        communication_error[window_index] = error
        accepted[window_index] = error <= limit
        interface_current[window_index + 1] = held_current +
            damping * residual / (2.0 * reference_impedance)
        source_branch_current = held_current
        source_branch_voltage = next_source_branch_voltage
        load_capacitor_current = next_load_capacitor_current
    end
    return IndependentLaggedRLCResult(
        time,
        interface_current,
        positive_voltage,
        negative_voltage,
        voltage_residual,
        communication_error,
        value_age,
        accepted,
    )
end
