struct IndependentShuntCompensatorEvent
    time_s::Float64
    kind::Symbol
    branch::Symbol
    phase::Int
    direction::Int8
end

struct IndependentSwitchingShuntCompensatorTrace
    time_s::Vector{Float64}
    source_voltage_v::Matrix{Float64}
    bus_voltage_v::Matrix{Float64}
    tcr_current_a::Matrix{Float64}
    tsc_current_a::Matrix{Float64}
    tsc_capacitor_voltage_v::Matrix{Float64}
    conducting_state::BitMatrix
    stored_energy_j::Vector{Float64}
    events::Vector{IndependentShuntCompensatorEvent}
end

struct IndependentSeriesCompensatorEvent
    time_s::Float64
    kind::Symbol
    phase::Int
    direction::Int8
end

struct IndependentSwitchingSeriesCompensatorTrace
    time_s::Vector{Float64}
    source_voltage_v::Matrix{Float64}
    sending_voltage_v::Matrix{Float64}
    receiving_voltage_v::Matrix{Float64}
    line_current_a::Matrix{Float64}
    capacitor_current_a::Matrix{Float64}
    reactor_current_a::Matrix{Float64}
    capacitor_voltage_v::Matrix{Float64}
    conducting_state::BitMatrix
    stored_energy_j::Vector{Float64}
    events::Vector{IndependentSeriesCompensatorEvent}
end

function independent_tcr_fundamental_susceptance(
    angular_frequency_rad_per_s::Real,
    inductance_h::Real,
    firing_angle_rad::Real,
)
    omega, inductance, firing_angle = Float64.((
        angular_frequency_rad_per_s,
        inductance_h,
        firing_angle_rad,
    ))
    all(isfinite, (omega, inductance, firing_angle)) && omega > 0.0 &&
        inductance > 0.0 && pi / 2 <= firing_angle <= pi || throw(ArgumentError(
        "independent TCR fundamental limit requires positive frequency and inductance with firing angle from pi/2 through pi",
    ))
    reactor_susceptance = inv(omega * inductance)
    return -(2.0 * reactor_susceptance / pi) * (
        pi - firing_angle + 0.5 * sin(2.0 * firing_angle)
    )
end

function independent_tsc_fundamental_susceptance(
    angular_frequency_rad_per_s::Real,
    capacitance_f::Real,
)
    omega, capacitance = Float64.((angular_frequency_rad_per_s, capacitance_f))
    all(isfinite, (omega, capacitance)) && omega > 0.0 && capacitance > 0.0 ||
        throw(ArgumentError(
            "independent TSC fundamental limit requires positive frequency and capacitance",
        ))
    return omega * capacitance
end

independent_svc_fundamental_susceptance(
    angular_frequency_rad_per_s::Real,
    inductance_h::Real,
    firing_angle_rad::Real,
    capacitance_f::Real,
) = independent_tcr_fundamental_susceptance(
    angular_frequency_rad_per_s,
    inductance_h,
    firing_angle_rad,
) + independent_tsc_fundamental_susceptance(
    angular_frequency_rad_per_s,
    capacitance_f,
)

function _independent_shunt_pulse_active(angle_rad, target_rad, width_rad)
    return mod(angle_rad - target_rad, 2pi) <= width_rad + 16eps(Float64)
end

function _independent_shunt_source_voltage(peak_v, omega, phase, time_s)
    return peak_v * sin(omega * time_s - 2pi * (phase - 1) / 3)
end

function _independent_shunt_turn_on_direction(
    angle_rad,
    positive_target_rad,
    width_rad,
    forward_voltage_v,
)
    if _independent_shunt_pulse_active(angle_rad, positive_target_rad, width_rad) &&
       forward_voltage_v > 0.0
        return Int8(1)
    elseif _independent_shunt_pulse_active(
        angle_rad,
        positive_target_rad + pi,
        width_rad,
    ) && forward_voltage_v < 0.0
        return Int8(-1)
    end
    return Int8(0)
end

function _independent_shunt_state_step(
    state,
    matrix,
    previous_source,
    current_source,
    step_s,
    topology_changed,
)
    identity = Matrix{Float64}(I, 3, 3)
    if topology_changed
        return (identity - step_s * matrix) \ (state + step_s * current_source)
    end
    return (identity - 0.5 * step_s * matrix) \ (
        (identity + 0.5 * step_s * matrix) * state +
        0.5 * step_s * (previous_source + current_source)
    )
end

"""Independently integrate an ideal finite-R/L/C TCR, TSC, or combined SVC.

This public reference owns its own dense state equation, firing calendar, latch and
current-zero recurrence. It imports no AIMORA production stamps, companions, valve
events, solver state, or private numerical implementation.
"""
function independent_switching_shunt_compensator_trace(;
    family::Symbol,
    source_phase_peak_voltage_v::Real,
    source_frequency_hz::Real,
    source_resistance_ohm::Real,
    tcr_resistance_ohm::Real=0.0,
    tcr_inductance_h::Real=1.0,
    tcr_firing_angle_rad::Real=pi,
    tsc_resistance_ohm::Real=0.0,
    tsc_damping_inductance_h::Real=0.0,
    tsc_capacitance_f::Real=1.0,
    tsc_connection_angle_rad::Real=pi / 2,
    valve_forward_voltage_v::Real=0.0,
    minimum_pulse_s::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    family in (:tcr, :tsc, :svc) || throw(ArgumentError(
        "independent shunt-compensator family must be :tcr, :tsc, or :svc",
    ))
    has_tcr = family in (:tcr, :svc)
    has_tsc = family in (:tsc, :svc)
    values = Float64.((
        source_phase_peak_voltage_v,
        source_frequency_hz,
        source_resistance_ohm,
        tcr_resistance_ohm,
        tcr_inductance_h,
        tcr_firing_angle_rad,
        tsc_resistance_ohm,
        tsc_damping_inductance_h,
        tsc_capacitance_f,
        tsc_connection_angle_rad,
        valve_forward_voltage_v,
        minimum_pulse_s,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent shunt-compensator inputs must be finite",
    ))
    peak, frequency, source_resistance, tcr_resistance, tcr_inductance,
        tcr_firing_angle, tsc_resistance, tsc_inductance, tsc_capacitance,
        tsc_connection_angle, valve_drop, pulse_width, start_time, stop_time,
        step = values
    peak > 0.0 && frequency > 0.0 && source_resistance > 0.0 &&
        tcr_resistance >= 0.0 && (!has_tcr || tcr_inductance > 0.0) &&
        pi / 2 <= tcr_firing_angle <= pi && tsc_resistance >= 0.0 &&
        (!has_tsc || tsc_inductance > 0.0) && tsc_capacitance > 0.0 &&
        0.0 <= tsc_connection_angle < 2pi && valve_drop >= 0.0 &&
        pulse_width > 0.0 && start_time >= 0.0 && stop_time > start_time &&
        step > 0.0 || throw(ArgumentError(
        "independent shunt-compensator physical or temporal domain is invalid",
    ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent shunt-compensator horizon must contain integer fixed steps",
        ))
    sample_count = step_count + 1
    valve_count = family === :svc ? 12 : 6
    time = [start_time + index * step for index in 0:step_count]
    source_voltage = zeros(Float64, 3, sample_count)
    bus_voltage = zeros(Float64, 3, sample_count)
    tcr_current = zeros(Float64, 3, sample_count)
    tsc_current = zeros(Float64, 3, sample_count)
    capacitor_voltage = zeros(Float64, 3, sample_count)
    conducting = falses(valve_count, sample_count)
    stored_energy = zeros(Float64, sample_count)
    events = IndependentShuntCompensatorEvent[]
    tcr_direction = zeros(Int8, 3)
    tsc_direction = zeros(Int8, 3)
    omega = 2pi * frequency
    pulse_angle = omega * max(pulse_width, step)
    for phase in 1:3
        source_voltage[phase, 1] = _independent_shunt_source_voltage(
            peak,
            omega,
            phase,
            start_time,
        )
        bus_voltage[phase, 1] = source_voltage[phase, 1]
    end
    for sample in 2:sample_count
        endpoint = time[sample]
        previous_time = time[sample - 1]
        for phase in 1:3
            previous_voltage = _independent_shunt_source_voltage(
                peak,
                omega,
                phase,
                previous_time,
            )
            current_voltage = _independent_shunt_source_voltage(
                peak,
                omega,
                phase,
                endpoint,
            )
            source_voltage[phase, sample] = current_voltage
            angle = mod(omega * endpoint - 2pi * (phase - 1) / 3, 2pi)
            topology_changed = false
            if has_tcr && iszero(tcr_direction[phase])
                direction = _independent_shunt_turn_on_direction(
                    angle,
                    tcr_firing_angle,
                    pulse_angle,
                    current_voltage,
                )
                if !iszero(direction)
                    tcr_direction[phase] = direction
                    topology_changed = true
                    push!(events, IndependentShuntCompensatorEvent(
                        endpoint,
                        :forward_turn_on,
                        :tcr,
                        phase,
                        direction,
                    ))
                end
            end
            if has_tsc && iszero(tsc_direction[phase])
                direction = _independent_shunt_turn_on_direction(
                    angle,
                    tsc_connection_angle,
                    pulse_angle,
                    current_voltage - capacitor_voltage[phase, sample - 1],
                )
                if !iszero(direction)
                    tsc_direction[phase] = direction
                    topology_changed = true
                    push!(events, IndependentShuntCompensatorEvent(
                        endpoint,
                        :forward_turn_on,
                        :tsc,
                        phase,
                        direction,
                    ))
                end
            end
            state = [
                tcr_current[phase, sample - 1],
                tsc_current[phase, sample - 1],
                capacitor_voltage[phase, sample - 1],
            ]
            matrix = zeros(Float64, 3, 3)
            previous_source = zeros(Float64, 3)
            current_source = zeros(Float64, 3)
            if !iszero(tcr_direction[phase])
                matrix[1, 1] = -(source_resistance + tcr_resistance) / tcr_inductance
                matrix[1, 2] = -source_resistance / tcr_inductance
                previous_source[1] = (
                    previous_voltage - tcr_direction[phase] * valve_drop
                ) / tcr_inductance
                current_source[1] = (
                    current_voltage - tcr_direction[phase] * valve_drop
                ) / tcr_inductance
            else
                state[1] = 0.0
            end
            if !iszero(tsc_direction[phase])
                matrix[2, 1] = -source_resistance / tsc_inductance
                matrix[2, 2] = -(source_resistance + tsc_resistance) / tsc_inductance
                matrix[2, 3] = -inv(tsc_inductance)
                matrix[3, 2] = inv(tsc_capacitance)
                previous_source[2] = (
                    previous_voltage - tsc_direction[phase] * valve_drop
                ) / tsc_inductance
                current_source[2] = (
                    current_voltage - tsc_direction[phase] * valve_drop
                ) / tsc_inductance
            else
                state[2] = 0.0
            end
            next_state = _independent_shunt_state_step(
                state,
                matrix,
                previous_source,
                current_source,
                step,
                topology_changed,
            )
            if !iszero(tcr_direction[phase]) &&
               tcr_direction[phase] * next_state[1] <= 0.0
                direction = tcr_direction[phase]
                tcr_direction[phase] = 0
                next_state[1] = 0.0
                push!(events, IndependentShuntCompensatorEvent(
                    endpoint,
                    :forward_extinction,
                    :tcr,
                    phase,
                    direction,
                ))
            end
            if !iszero(tsc_direction[phase]) &&
               tsc_direction[phase] * next_state[2] <= 0.0
                direction = tsc_direction[phase]
                tsc_direction[phase] = 0
                next_state[2] = 0.0
                push!(events, IndependentShuntCompensatorEvent(
                    endpoint,
                    :forward_extinction,
                    :tsc,
                    phase,
                    direction,
                ))
            end
            tcr_current[phase, sample] = next_state[1]
            tsc_current[phase, sample] = next_state[2]
            capacitor_voltage[phase, sample] = next_state[3]
            bus_voltage[phase, sample] = current_voltage - source_resistance * (
                next_state[1] + next_state[2]
            )
            tcr_offset = 0
            tsc_offset = has_tcr ? 6 : 0
            if !iszero(tcr_direction[phase])
                conducting[tcr_offset + 2phase - (tcr_direction[phase] > 0), sample] = true
            end
            if !iszero(tsc_direction[phase])
                conducting[tsc_offset + 2phase - (tsc_direction[phase] > 0), sample] = true
            end
        end
        stored_energy[sample] = 0.5 * (
            tcr_inductance * sum(abs2, tcr_current[:, sample]) +
            tsc_inductance * sum(abs2, tsc_current[:, sample]) +
            tsc_capacitance * sum(abs2, capacitor_voltage[:, sample])
        )
    end
    return IndependentSwitchingShuntCompensatorTrace(
        time,
        source_voltage,
        bus_voltage,
        tcr_current,
        tsc_current,
        capacitor_voltage,
        conducting,
        stored_energy,
        events,
    )
end

"""Independently integrate one finite three-phase switching TCSC circuit.

Each phase is a Thevenin source and series R-L load separated by a capacitor in
parallel with a fired R-L reactor. The reference advances its own dense state
equation and ideal directional latch; it imports no AIMORA production stamp,
companion, event, semiconductor state, or private solver implementation.
"""
function independent_switching_series_compensator_trace(;
    source_phase_peak_voltage_v::Real,
    source_frequency_hz::Real,
    source_resistance_ohm::Real,
    load_resistance_ohm::Real,
    load_inductance_h::Real,
    capacitance_f::Real,
    reactor_resistance_ohm::Real,
    reactor_inductance_h::Real,
    firing_angle_rad::Real,
    valve_forward_voltage_v::Real=0.0,
    minimum_pulse_s::Real,
    start_time_s::Real=0.0,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    values = Float64.((
        source_phase_peak_voltage_v,
        source_frequency_hz,
        source_resistance_ohm,
        load_resistance_ohm,
        load_inductance_h,
        capacitance_f,
        reactor_resistance_ohm,
        reactor_inductance_h,
        firing_angle_rad,
        valve_forward_voltage_v,
        minimum_pulse_s,
        start_time_s,
        stop_time_s,
        fixed_step_s,
    ))
    all(isfinite, values) || throw(ArgumentError(
        "independent series-compensator inputs must be finite",
    ))
    peak, frequency, source_resistance, load_resistance, load_inductance,
        capacitance, reactor_resistance, reactor_inductance, firing_angle,
        valve_drop, pulse_width, start_time, stop_time, step = values
    peak > 0.0 && frequency > 0.0 && source_resistance > 0.0 &&
        load_resistance > 0.0 && load_inductance > 0.0 && capacitance > 0.0 &&
        reactor_resistance >= 0.0 && reactor_inductance > 0.0 &&
        pi / 2 <= firing_angle <= pi && valve_drop >= 0.0 && pulse_width > 0.0 &&
        start_time >= 0.0 && stop_time > start_time && step > 0.0 ||
        throw(ArgumentError(
            "independent series-compensator physical or temporal domain is invalid",
        ))
    step_count_real = (stop_time - start_time) / step
    step_count = round(Int, step_count_real)
    isapprox(step_count_real, step_count; atol=1.0e-10, rtol=1.0e-10) ||
        throw(ArgumentError(
            "independent series-compensator horizon must contain integer fixed steps",
        ))
    sample_count = step_count + 1
    omega = 2pi * frequency
    pulse_angle = omega * pulse_width + 16eps(Float64)
    time = [start_time + index * step for index in 0:step_count]
    source_voltage = zeros(Float64, 3, sample_count)
    sending_voltage = zeros(Float64, 3, sample_count)
    receiving_voltage = zeros(Float64, 3, sample_count)
    line_current = zeros(Float64, 3, sample_count)
    capacitor_current = zeros(Float64, 3, sample_count)
    reactor_current = zeros(Float64, 3, sample_count)
    capacitor_voltage = zeros(Float64, 3, sample_count)
    conducting = falses(6, sample_count)
    stored_energy = zeros(Float64, sample_count)
    direction = zeros(Int8, 3)
    events = IndependentSeriesCompensatorEvent[]
    for phase in 1:3
        source_voltage[phase, 1] = _independent_shunt_source_voltage(
            peak,
            omega,
            phase,
            start_time,
        )
        sending_voltage[phase, 1] = source_voltage[phase, 1]
        receiving_voltage[phase, 1] = source_voltage[phase, 1]
    end
    identity = Matrix{Float64}(I, 3, 3)
    for sample in 2:sample_count
        previous_time = time[sample - 1]
        endpoint = time[sample]
        for phase in 1:3
            previous_source_voltage = _independent_shunt_source_voltage(
                peak,
                omega,
                phase,
                previous_time,
            )
            current_source_voltage = _independent_shunt_source_voltage(
                peak,
                omega,
                phase,
                endpoint,
            )
            source_voltage[phase, sample] = current_source_voltage
            state = Float64[
                line_current[phase, sample - 1],
                reactor_current[phase, sample - 1],
                capacitor_voltage[phase, sample - 1],
            ]
            topology_changed = false
            if iszero(direction[phase])
                angle = mod(omega * endpoint - 2pi * (phase - 1) / 3, 2pi)
                positive_firing = _independent_shunt_pulse_active(
                    angle,
                    firing_angle,
                    pulse_angle,
                )
                negative_firing = _independent_shunt_pulse_active(
                    angle,
                    firing_angle + pi,
                    pulse_angle,
                )
                direction[phase] = positive_firing && state[3] > valve_drop ?
                    Int8(1) : negative_firing && state[3] < -valve_drop ?
                    Int8(-1) : Int8(0)
                if !iszero(direction[phase])
                    topology_changed = true
                    push!(events, IndependentSeriesCompensatorEvent(
                        endpoint,
                        :forward_turn_on,
                        phase,
                        direction[phase],
                    ))
                end
            end
            active = !iszero(direction[phase])
            matrix = zeros(Float64, 3, 3)
            matrix[1, 1] = -(source_resistance + load_resistance) /
                load_inductance
            matrix[1, 3] = -inv(load_inductance)
            matrix[3, 1] = inv(capacitance)
            previous_source = [previous_source_voltage / load_inductance, 0.0, 0.0]
            current_source = [current_source_voltage / load_inductance, 0.0, 0.0]
            if active
                matrix[2, 2] = -reactor_resistance / reactor_inductance
                matrix[2, 3] = inv(reactor_inductance)
                matrix[3, 2] = -inv(capacitance)
                valve_source = -direction[phase] * valve_drop / reactor_inductance
                previous_source[2] = valve_source
                current_source[2] = valve_source
            else
                state[2] = 0.0
            end
            next_state = if topology_changed
                (identity - step * matrix) \ (state + step * current_source)
            else
                (identity - 0.5step * matrix) \ (
                    (identity + 0.5step * matrix) * state +
                    0.5step * (previous_source + current_source)
                )
            end
            if active && direction[phase] * next_state[2] <= 0.0
                extinguished_direction = direction[phase]
                direction[phase] = 0
                next_state[2] = 0.0
                push!(events, IndependentSeriesCompensatorEvent(
                    endpoint,
                    :forward_extinction,
                    phase,
                    extinguished_direction,
                ))
            end
            line_current[phase, sample] = next_state[1]
            reactor_current[phase, sample] = next_state[2]
            capacitor_voltage[phase, sample] = next_state[3]
            capacitor_current[phase, sample] = next_state[1] - next_state[2]
            sending_voltage[phase, sample] = current_source_voltage -
                source_resistance * next_state[1]
            receiving_voltage[phase, sample] = sending_voltage[phase, sample] -
                next_state[3]
            if !iszero(direction[phase])
                conducting[2phase - (direction[phase] > 0), sample] = true
            end
        end
        stored_energy[sample] = 0.5 * (
            load_inductance * sum(abs2, line_current[:, sample]) +
            reactor_inductance * sum(abs2, reactor_current[:, sample]) +
            capacitance * sum(abs2, capacitor_voltage[:, sample])
        )
    end
    return IndependentSwitchingSeriesCompensatorTrace(
        time,
        source_voltage,
        sending_voltage,
        receiving_voltage,
        line_current,
        capacitor_current,
        reactor_current,
        capacitor_voltage,
        conducting,
        stored_energy,
        events,
    )
end

"""Return the lossless terminal-angle displacement from one signed quadrature tap.

The construction is independent of AIMORA transformer stamps: a declared series
injection `j * polarity * ratio * V` gives `angle(1 + j * polarity * ratio)`.
"""
function independent_quadrature_phase_shift_rad(
    injection_ratio::Real,
    polarity::Integer,
)
    ratio = Float64(injection_ratio)
    polarity_value = Int(polarity)
    isfinite(ratio) && 0.0 < ratio <= 0.5 && polarity_value in (-1, 1) ||
        throw(ArgumentError(
            "independent quadrature phase shift requires a ratio in (0, 0.5] and polarity -1 or +1",
        ))
    return atan(polarity_value * ratio)
end

"""Return balanced lossless three-phase active transfer through series reactance.

Line-line RMS voltage and reactance are SI quantities. Positive power follows the
declared sending-to-receiving orientation, and the signed quadrature tap augments
the pre-existing sending-minus-receiving angle.
"""
function independent_quadrature_phase_shifter_power_w(
    line_line_rms_voltage_v::Real,
    series_reactance_ohm::Real,
    base_angle_rad::Real,
    injection_ratio::Real,
    polarity::Integer,
)
    voltage, reactance, base_angle = Float64.((
        line_line_rms_voltage_v,
        series_reactance_ohm,
        base_angle_rad,
    ))
    all(isfinite, (voltage, reactance, base_angle)) && voltage > 0.0 &&
        reactance > 0.0 && abs(base_angle) <= pi || throw(ArgumentError(
        "independent phase-shifter power requires positive finite voltage/reactance and a base angle within [-pi, pi]",
    ))
    shift = independent_quadrature_phase_shift_rad(injection_ratio, polarity)
    return voltage^2 / reactance * sin(base_angle + shift)
end

"""Independently evaluate instantaneous three-phase active and reactive power.

The formula is written directly in stationary Clarke coordinates and does not
reuse the production VSC transforms, controller, bridge, stamp, or result code.
Positive current follows the caller's declared terminal orientation. The same
equation therefore covers shunt, series, line, UPFC, and IPFC terminals.
"""
function independent_three_phase_instantaneous_power(
    phase_voltage_v::NTuple{3,<:Real},
    phase_current_a::NTuple{3,<:Real},
)
    voltage = Float64.(phase_voltage_v)
    current = Float64.(phase_current_a)
    all(isfinite, (voltage..., current...)) || throw(ArgumentError(
        "independent three-phase voltage and current must be finite",
    ))
    voltage_alpha = (2voltage[1] - voltage[2] - voltage[3]) / 3
    voltage_beta = (voltage[2] - voltage[3]) / sqrt(3.0)
    voltage_zero = sum(voltage) / 3
    current_alpha = (2current[1] - current[2] - current[3]) / 3
    current_beta = (current[2] - current[3]) / sqrt(3.0)
    current_zero = sum(current) / 3
    return (
        active_w=1.5 * (
            voltage_alpha * current_alpha + voltage_beta * current_beta
        ) + 3.0 * voltage_zero * current_zero,
        reactive_var=1.5 * (
            voltage_beta * current_alpha - voltage_alpha * current_beta
        ),
    )
end

"""Compatibility entrypoint for the independently evaluated STATCOM P and Q."""
independent_statcom_instantaneous_power(phase_voltage_v, phase_current_a) =
    independent_three_phase_instantaneous_power(
        phase_voltage_v,
        phase_current_a,
    )

"""Independently evaluate electrostatic energy stored in a converter DC link."""
function independent_dc_link_energy_j(
    dc_link_capacitance_f::Real,
    dc_link_voltage_v::Real,
)
    capacitance = Float64(dc_link_capacitance_f)
    voltage = Float64(dc_link_voltage_v)
    isfinite(capacitance) && capacitance > 0.0 && isfinite(voltage) ||
        throw(ArgumentError(
            "independent DC-link energy requires positive finite capacitance and finite voltage",
        ))
    return 0.5 * capacitance * voltage^2
end

"""Compatibility entrypoint for independently evaluated STATCOM DC-link energy."""
independent_statcom_dc_link_energy_j(dc_link_capacitance_f, dc_link_voltage_v) =
    independent_dc_link_energy_j(
        dc_link_capacitance_f,
        dc_link_voltage_v,
    )

"""Return the signed STATCOM DC-link instantaneous energy-balance residual."""
function independent_statcom_dc_energy_residual_w(
    dc_link_input_power_w::Real,
    dc_link_output_power_w::Real,
    loss_power_w::Real,
    dc_link_capacitance_f::Real,
    dc_link_voltage_v::Real,
    dc_link_voltage_derivative_v_per_s::Real,
)
    values = Float64.((
        dc_link_input_power_w,
        dc_link_output_power_w,
        loss_power_w,
        dc_link_capacitance_f,
        dc_link_voltage_v,
        dc_link_voltage_derivative_v_per_s,
    ))
    all(isfinite, values) && values[4] > 0.0 && values[5] > 0.0 &&
        values[3] >= 0.0 || throw(ArgumentError(
        "independent STATCOM DC-energy inputs must be finite with positive capacitance/voltage and nonnegative loss",
    ))
    input_power, output_power, loss, capacitance, voltage, derivative = values
    return input_power - output_power - loss - capacitance * voltage * derivative
end

function independent_lcc_six_pulse_no_load_voltage_v(
    ac_line_line_rms_voltage_v::Real,
)
    voltage = Float64(ac_line_line_rms_voltage_v)
    isfinite(voltage) && voltage > 0.0 || throw(ArgumentError(
        "independent LCC no-load voltage requires positive finite line-line RMS voltage",
    ))
    return 3sqrt(2.0) * voltage / pi
end

function independent_lcc_six_pulse_average_voltage_v(
    ac_line_line_rms_voltage_v::Real,
    firing_angle_rad::Real,
    commutating_inductance_h::Real,
    dc_current_a::Real,
    frequency_hz::Real,
)
    angle, inductance, current, frequency = Float64.((
        firing_angle_rad,
        commutating_inductance_h,
        dc_current_a,
        frequency_hz,
    ))
    all(isfinite, (angle, inductance, current, frequency)) &&
        0.0 <= angle <= pi && inductance >= 0.0 && current >= 0.0 &&
        frequency > 0.0 || throw(ArgumentError(
            "independent LCC average voltage inputs are outside their physical domain",
        ))
    return independent_lcc_six_pulse_no_load_voltage_v(
        ac_line_line_rms_voltage_v,
    ) * cos(angle) - 6.0 * frequency * inductance * current
end

function independent_lcc_extinction_angle_rad(
    firing_angle_rad::Real,
    overlap_angle_rad::Real,
)
    firing, overlap = Float64.((firing_angle_rad, overlap_angle_rad))
    all(isfinite, (firing, overlap)) && firing >= 0.0 && overlap >= 0.0 &&
        firing + overlap <= pi || throw(ArgumentError(
            "independent LCC extinction requires nonnegative firing/overlap whose sum does not exceed pi",
        ))
    return pi - firing - overlap
end

function independent_lcc_vdcol_current_order_a(
    voltage_breakpoints_v,
    current_breakpoints_a,
    dc_voltage_v::Real,
)
    voltage = Float64.(voltage_breakpoints_v)
    current = Float64.(current_breakpoints_a)
    query = Float64(dc_voltage_v)
    length(voltage) == length(current) >= 2 && all(isfinite, voltage) &&
        all(isfinite, current) && all(>=(0.0), voltage) && all(>=(0.0), current) &&
        issorted(voltage) && length(unique(voltage)) == length(voltage) &&
        issorted(current) && isfinite(query) && query >= 0.0 || throw(ArgumentError(
            "independent LCC VDCOL requires ordered nonnegative finite breakpoints and query",
        ))
    query <= first(voltage) && return first(current)
    query >= last(voltage) && return last(current)
    upper = searchsortedfirst(voltage, query)
    lower = upper - 1
    fraction = (query - voltage[lower]) / (voltage[upper] - voltage[lower])
    return current[lower] + fraction * (current[upper] - current[lower])
end

independent_lcc_pole_balance_residual_a(
    positive_pole_current_a::Real,
    negative_pole_current_a::Real,
    metallic_return_current_a::Real,
) = Float64(positive_pole_current_a) + Float64(negative_pole_current_a) -
    Float64(metallic_return_current_a)

struct IndependentLCCHVDCTrace
    time_s::Vector{Float64}
    pole_current_a::Matrix{Float64}
    rectifier_average_voltage_v::Matrix{Float64}
    inverter_average_voltage_v::Matrix{Float64}
    extinction_angle_rad::Matrix{Float64}
    vdcol_current_order_a::Matrix{Float64}
    smoothing_energy_j::Vector{Float64}
    metallic_return_current_a::Vector{Float64}
end

"""Independently integrate the admitted balanced LCC DC-link limit.

This recurrence uses the published six-pulse average bridge law, explicit pulse
group count, smoothing/link R-L state, VDCOL interpolation, and pole signs. It
does not import production bridge, transformer, nodal, event, controller, or
private solver code and therefore remains a separate limiting formulation.
"""
function independent_lcc_hvdc_trace(;
    pulse_count::Integer,
    pole_polarities,
    ac_line_line_rms_voltage_v::Real,
    source_frequency_hz::Real,
    rectifier_firing_angle_rad::Real,
    inverter_firing_angle_rad::Real,
    commutating_inductance_h::Real,
    smoothing_and_line_resistance_ohm::Real,
    smoothing_and_line_inductance_h::Real,
    initial_pole_current_a::Real,
    vdcol_voltage_breakpoints_v,
    vdcol_current_breakpoints_a,
    stop_time_s::Real,
    fixed_step_s::Real,
)
    pulses = Int(pulse_count)
    pulses in (6, 12) || throw(ArgumentError(
        "independent LCC trace admits exactly six or twelve pulses",
    ))
    polarities = Tuple(Int8.(pole_polarities))
    polarities in ((Int8(1),), (Int8(1), Int8(-1))) || throw(ArgumentError(
        "independent LCC trace admits one positive pole or an ordered symmetric bipole",
    ))
    voltage, frequency, rectifier_angle, inverter_angle, commutating_inductance,
        resistance, inductance, initial_current, stop_time, step = Float64.((
            ac_line_line_rms_voltage_v,
            source_frequency_hz,
            rectifier_firing_angle_rad,
            inverter_firing_angle_rad,
            commutating_inductance_h,
            smoothing_and_line_resistance_ohm,
            smoothing_and_line_inductance_h,
            initial_pole_current_a,
            stop_time_s,
            fixed_step_s,
        ))
    all(isfinite, (
        voltage,
        frequency,
        rectifier_angle,
        inverter_angle,
        commutating_inductance,
        resistance,
        inductance,
        initial_current,
        stop_time,
        step,
    )) && voltage > 0.0 && frequency > 0.0 &&
        0.0 <= rectifier_angle <= pi && 0.0 <= inverter_angle <= pi &&
        commutating_inductance >= 0.0 && resistance >= 0.0 &&
        inductance > 0.0 && initial_current >= 0.0 && stop_time > 0.0 &&
        step > 0.0 || throw(ArgumentError(
            "independent LCC trace parameters are outside their finite physical domains",
        ))
    step_count = round(Int, stop_time / step)
    isapprox(step_count * step, stop_time; atol=1.0e-12, rtol=1.0e-12) ||
        throw(ArgumentError(
            "independent LCC trace horizon must contain integer fixed steps",
        ))
    pole_count = length(polarities)
    group_count = pulses ÷ 6
    time_s = collect(0:step_count) .* step
    pole_current_a = zeros(pole_count, step_count + 1)
    rectifier_voltage_v = zeros(pole_count, step_count + 1)
    inverter_voltage_v = zeros(pole_count, step_count + 1)
    extinction_angle_rad = fill(
        independent_lcc_extinction_angle_rad(inverter_angle, 0.0),
        pole_count,
        step_count + 1,
    )
    current_order_a = zeros(pole_count, step_count + 1)
    smoothing_energy_j = zeros(step_count + 1)
    metallic_return_current_a = zeros(step_count + 1)
    pole_current_a[:, 1] .= polarities .* initial_current
    for sample in 1:(step_count + 1)
        for pole in 1:pole_count
            current = abs(pole_current_a[pole, sample])
            rectifier_voltage_v[pole, sample] = group_count *
                independent_lcc_six_pulse_average_voltage_v(
                    voltage,
                    rectifier_angle,
                    commutating_inductance,
                    current,
                    frequency,
                )
            inverter_voltage_v[pole, sample] = group_count *
                independent_lcc_six_pulse_average_voltage_v(
                    voltage,
                    inverter_angle,
                    commutating_inductance,
                    current,
                    frequency,
                )
            dc_magnitude = max(
                abs(rectifier_voltage_v[pole, sample]),
                abs(inverter_voltage_v[pole, sample]),
            )
            current_order_a[pole, sample] =
                independent_lcc_vdcol_current_order_a(
                    vdcol_voltage_breakpoints_v,
                    vdcol_current_breakpoints_a,
                    dc_magnitude,
                )
        end
        smoothing_energy_j[sample] = 0.5 * inductance *
            sum(abs2, pole_current_a[:, sample])
        metallic_return_current_a[sample] = sum(pole_current_a[:, sample])
        sample == step_count + 1 && continue
        for pole in 1:pole_count
            signed_drive = polarities[pole] * (
                rectifier_voltage_v[pole, sample] +
                inverter_voltage_v[pole, sample]
            )
            pole_current_a[pole, sample + 1] = (
                pole_current_a[pole, sample] + step * signed_drive / inductance
            ) / (1.0 + step * resistance / inductance)
        end
    end
    return IndependentLCCHVDCTrace(
        time_s,
        pole_current_a,
        rectifier_voltage_v,
        inverter_voltage_v,
        extinction_angle_rad,
        current_order_a,
        smoothing_energy_j,
        metallic_return_current_a,
    )
end
