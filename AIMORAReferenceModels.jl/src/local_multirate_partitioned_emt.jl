export IndependentPassiveLadderResult,
       IndependentPartitionedRLCResult,
       independent_exact_passive_ladder,
       independent_exact_passive_rlc,
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
