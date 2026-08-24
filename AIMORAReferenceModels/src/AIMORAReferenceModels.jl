"""Small analytical and manufactured public reference-model boundary for independent AIMORA checks."""
module AIMORAReferenceModels

using LinearAlgebra
using SHA

export amplitude_invariant_clarke_matrix,
       synchronous_reference_rotation_matrix,
       phase_to_synchronous_reference,
       synchronous_to_phase_reference,
       two_level_pwm_duties,
       synchronous_current_control_reference,
       exponential_conductance_voltage_reference,
       cubic_mna_residual_jacobian_reference,
       manufactured_cubic_constraint_case,
       IndependentHarmonicNetworkResult,
       trapezoidal_reactive_angular_frequency,
       independent_series_rl_network_equilibrium,
       independent_series_rl_recurrence_residuals,
       independent_lumped_companion_periodic_state,
       independent_lumped_companion_recurrence_residual,
       independent_coupled_series_rl_periodic_state,
       independent_coupled_series_rl_recurrence_residuals,
       independent_peak_phasor_samples,
       independent_periodic_voltage_error,
       independent_operating_point_mapping,
       sampled_saturating_lag_reference,
       passive_cubic_branch_reference,
       series_rl_trapezoidal_reference,
       directed_linear_event_root_reference,
       IndependentTaskCalendarSpec,
       IndependentTaskOccurrence,
       IndependentTaskReferenceResult,
       independent_multirate_task_reference,
       IndependentSemiconductorState,
       independent_recovered_charge_backward_euler,
       independent_junction_capacitance,
       independent_junction_charge,
       independent_junction_energy,
       independent_turn_off_tail,
       independent_trilinear_semiconductor_energy,
       independent_cauer_backward_euler,
       IndependentBridgeTopology,
       independent_bridge_topology,
       independent_bridge_incidence,
       independent_bridge_kcl,
       independent_bridge_terminal_power,
       independent_bridge_state_is_allowed,
       independent_bridge_passive_backward_euler,
       independent_cascaded_h_bridge_voltage,
       independent_vsc_current_projection,
       independent_vsc_power_current_reference,
       independent_vsc_pll_sample,
       independent_vsc_resonator_sample,
       independent_vsc_power_filter_sample,
       independent_vsc_droop_sample,
       independent_vsc_swing_sample,
       independent_vsc_instantaneous_power,
       independent_vsc_sequence_components,
       independent_vsc_capacitor_companion_residual,
       series_rl_piecewise_constant_current,
       series_rl_piecewise_constant_trace,
       IndependentPortableArray,
       IndependentPortableRecord,
       IndependentPortableMetadata,
       IndependentPortableSection,
       IndependentPortableSnapshot,
       independent_portable_array,
       independent_portable_array_values,
       independent_portable_snapshot_bytes,
       independent_decode_portable_snapshot,
       IndependentPortableHybridTaskOccurrence,
       IndependentPortableHybridEventOccurrence,
       IndependentPortableHybridReference,
       independent_portable_hybrid_reference,
       IndependentPassiveRLCDAEParameters,
       independent_bdf_derivative_weights,
       independent_passive_rlc_bdf_step,
       independent_passive_rlc_dae_residual,
       independent_passive_rlc_energy_balance,
       independent_passive_rlc_exact_state,
       independent_passive_rlc_initial_derivative,
       IndependentManufacturedIndexOneDAEParameters,
       independent_manufactured_index_one_state,
       independent_manufactured_index_one_derivative,
       independent_manufactured_index_one_residual,
       independent_manufactured_index_one_jacobians,
       IndependentRobertsonDAEParameters,
       independent_robertson_dae_residual,
       independent_robertson_dae_jacobians,
       independent_robertson_backward_euler,
       independent_scaled_linear_residual,
       independent_indexed_collection,
       independent_realtime_release_ns,
       independent_realtime_metrics,
       independent_affine_channel_value,
       independent_loopback_controller_step,
       independent_realtime_replay_signature

export independent_magnitude_timer_trace,
       independent_directional_torque,
       independent_mho_margin,
       independent_polygon_margin,
       independent_biased_differential,
       independent_rocof_trace,
       independent_incremental_wave_trace,
       independent_protection_message_calendar,
       independent_breaker_load_voltage,
       independent_contact_energy_trace,
       independent_breaker_failure

export independent_double_exponential_lightning,
       independent_double_exponential_integrals,
       independent_heidler_lightning,
       independent_combined_arc_step,
       independent_fault_arc_step,
       independent_vacuum_surfaces,
       independent_metal_oxide_characteristic,
       independent_arrester_duty_step,
       independent_positive_real_grounding,
       independent_ionizing_ground_step,
       independent_traveling_wave_state,
       independent_traveling_wave_reflection,
       independent_disruptive_effect_step,
       independent_leader_progression_step,
       independent_corona_charge,
       independent_gis_gil_matrices,
       independent_wilson_interval

include("extended_semiconductor_fidelity.jl")
include("generic_bridge_topologies.jl")
include("extended_vsc_control_filter_platform.jl")
include("wideband_line_parameters.jl")
include("coupled_line_fitting_passivity.jl")
include("coupled_line_runtime.jl")
include("transformer_apparatus.jl")
include("modern_machine_families.jl")
include("portable_emt_snapshots.jl")
include("local_multirate_partitioned_emt.jl")
include("dassl_class_variable_step_emt.jl")
include("performance_realtime_hil.jl")
include("emt_protection_breaker.jl")
include("surge_insulation.jl")

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

"""Solve `g*v + Is*expm1(v/Vs) = source_current` by an independent monotone bracket and bisection reference."""
function exponential_conductance_voltage_reference(
    source_current_a::Real,
    linear_conductance_s::Real,
    saturation_current_a::Real,
    voltage_scale_v::Real;
    current_tolerance_a::Real=1.0e-14,
    maximum_iterations::Integer=256,
)
    source_current = Float64(source_current_a)
    linear_conductance = Float64(linear_conductance_s)
    saturation_current = Float64(saturation_current_a)
    voltage_scale = Float64(voltage_scale_v)
    tolerance = Float64(current_tolerance_a)
    all(isfinite, (
        source_current,
        linear_conductance,
        saturation_current,
        voltage_scale,
        tolerance,
    )) || throw(ArgumentError("exponential reference inputs must be finite"))
    linear_conductance >= 0.0 || throw(ArgumentError(
        "reference linear conductance must be nonnegative",
    ))
    saturation_current > 0.0 || throw(ArgumentError(
        "reference saturation current must be positive",
    ))
    voltage_scale > 0.0 || throw(ArgumentError(
        "reference voltage scale must be positive",
    ))
    tolerance > 0.0 || throw(ArgumentError(
        "reference current tolerance must be positive",
    ))
    iterations = Int(maximum_iterations)
    iterations > 0 || throw(ArgumentError("reference maximum iterations must be positive"))

    residual(voltage_v) = linear_conductance * voltage_v +
        saturation_current * expm1(voltage_v / voltage_scale) - source_current
    zero_residual = residual(0.0)
    abs(zero_residual) <= tolerance && return 0.0
    lower_voltage = zero_residual > 0.0 ? -voltage_scale : 0.0
    upper_voltage = zero_residual > 0.0 ? 0.0 : voltage_scale
    lower_residual = residual(lower_voltage)
    upper_residual = residual(upper_voltage)
    expansion_count = 0
    while !(lower_residual <= 0.0 <= upper_residual)
        expansion_count += 1
        expansion_count <= 128 || throw(ArgumentError(
            "exponential reference could not bracket the monotone solution",
        ))
        if lower_residual > 0.0
            lower_voltage *= 2.0
            lower_residual = residual(lower_voltage)
        else
            upper_voltage *= 2.0
            upper_residual = residual(upper_voltage)
        end
        all(isfinite, (lower_residual, upper_residual)) || throw(ArgumentError(
            "exponential reference bracket left the finite evaluation domain",
        ))
    end
    for _ in 1:iterations
        midpoint = lower_voltage + 0.5 * (upper_voltage - lower_voltage)
        midpoint_residual = residual(midpoint)
        abs(midpoint_residual) <= tolerance && return midpoint
        if midpoint_residual < 0.0
            lower_voltage = midpoint
        else
            upper_voltage = midpoint
        end
    end
    midpoint = lower_voltage + 0.5 * (upper_voltage - lower_voltage)
    abs(residual(midpoint)) <= 10.0 * tolerance || throw(ArgumentError(
        "exponential reference did not reach its current tolerance",
    ))
    return midpoint
end

"""Independently assemble dense KCL/MNA residual and Jacobian for one passive cubic branch and one ideal voltage equation."""
function cubic_mna_residual_jacobian_reference(
    voltage_v,
    constraint_current_a::Real,
    linear_admittance_s,
    source_current_a,
    positive_node::Integer,
    negative_node::Integer,
    linear_conductance_s::Real,
    cubic_coefficient_a_per_v3::Real,
    constraint_coefficients,
    constraint_value_v::Real,
)
    voltage = Float64.(voltage_v)
    admittance = Matrix{Float64}(linear_admittance_s)
    source_current = Float64.(source_current_a)
    node_count = length(voltage)
    size(admittance) == (node_count, node_count) || throw(DimensionMismatch(
        "reference admittance size must match voltage count",
    ))
    length(source_current) == node_count || throw(DimensionMismatch(
        "reference source-current length must match voltage count",
    ))
    coefficients = Float64.(constraint_coefficients)
    length(coefficients) == node_count || throw(DimensionMismatch(
        "reference constraint coefficients must cover every node",
    ))
    positive = Int(positive_node)
    negative = Int(negative_node)
    1 <= positive <= node_count || throw(ArgumentError(
        "reference positive branch node is outside the network",
    ))
    1 <= negative <= node_count || throw(ArgumentError(
        "reference negative branch node is outside the network",
    ))
    positive != negative || throw(ArgumentError("reference cubic branch must not self-loop"))
    linear_conductance = Float64(linear_conductance_s)
    cubic_coefficient = Float64(cubic_coefficient_a_per_v3)
    constraint_current = Float64(constraint_current_a)
    constraint_value = Float64(constraint_value_v)
    all(isfinite, voltage) && all(isfinite, admittance) &&
        all(isfinite, source_current) && all(isfinite, coefficients) &&
        all(isfinite, (
            linear_conductance,
            cubic_coefficient,
            constraint_current,
            constraint_value,
        )) || throw(ArgumentError("reference cubic MNA inputs must be finite"))

    residual = admittance * voltage - source_current
    jacobian = zeros(Float64, node_count + 1, node_count + 1)
    jacobian[1:node_count, 1:node_count] .= admittance
    branch_voltage = voltage[positive] - voltage[negative]
    branch_current = linear_conductance * branch_voltage +
        cubic_coefficient * branch_voltage^3
    differential_conductance = linear_conductance +
        3.0 * cubic_coefficient * branch_voltage^2
    residual[positive] += branch_current
    residual[negative] -= branch_current
    jacobian[positive, positive] += differential_conductance
    jacobian[positive, negative] -= differential_conductance
    jacobian[negative, positive] -= differential_conductance
    jacobian[negative, negative] += differential_conductance
    residual .+= coefficients .* constraint_current
    constraint_residual = dot(coefficients, voltage) - constraint_value
    jacobian[1:node_count, end] .= coefficients
    jacobian[end, 1:node_count] .= coefficients
    complete_residual = vcat(residual, constraint_residual)
    nonlinear_device_absorbed_power_w = branch_voltage * branch_current
    ideal_constraint_absorbed_power_w =
        constraint_current * dot(coefficients, voltage)
    algebraic_power_balance_residual_w = dot(
        vcat(voltage, constraint_current),
        complete_residual,
    )
    return (
        residual=complete_residual,
        jacobian,
        branch_current_a=branch_current,
        branch_differential_conductance_s=differential_conductance,
        nonlinear_device_absorbed_power_w,
        ideal_constraint_absorbed_power_w,
        algebraic_power_balance_residual_w,
    )
end

"""Return a manufactured two-node cubic network whose exact voltage is `[2, 1]` V and constraint current is `0.4` A."""
function manufactured_cubic_constraint_case()
    exact_voltage_v = [2.0, 1.0]
    exact_constraint_current_a = 0.4
    linear_admittance_s = [1.0 0.0; 0.0 1.0]
    source_current_a = [2.7, 0.3]
    constraint_coefficients = [1.0, -1.0]
    evaluation = cubic_mna_residual_jacobian_reference(
        exact_voltage_v,
        exact_constraint_current_a,
        linear_admittance_s,
        source_current_a,
        1,
        2,
        0.2,
        0.1,
        constraint_coefficients,
        1.0,
    )
    return (
        exact_voltage_v,
        exact_constraint_current_a,
        linear_admittance_s,
        source_current_a,
        positive_node=1,
        negative_node=2,
        linear_conductance_s=0.2,
        cubic_coefficient_a_per_v3=0.1,
        constraint_coefficients,
        constraint_value_v=1.0,
        residual=evaluation.residual,
        jacobian=evaluation.jacobian,
        nonlinear_device_absorbed_power_w=
            evaluation.nonlinear_device_absorbed_power_w,
        ideal_constraint_absorbed_power_w=
            evaluation.ideal_constraint_absorbed_power_w,
        algebraic_power_balance_residual_w=
            evaluation.algebraic_power_balance_residual_w,
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

"""Advance an independently formulated zero-order-held first-order lag and apply output saturation."""
function sampled_saturating_lag_reference(
    previous_state::Real,
    held_input::Real,
    gain::Real,
    time_constant_s::Real,
    task_interval_s::Real,
    minimum_output::Real,
    maximum_output::Real,
)
    state, input, gain_value, time_constant, interval, minimum, maximum = Float64.((
        previous_state,
        held_input,
        gain,
        time_constant_s,
        task_interval_s,
        minimum_output,
        maximum_output,
    ))
    all(isfinite, (state, input, gain_value, time_constant, interval, minimum, maximum)) ||
        throw(ArgumentError("sampled-lag reference inputs must be finite"))
    time_constant > 0.0 || throw(ArgumentError(
        "sampled-lag reference time constant must be positive",
    ))
    interval > 0.0 || throw(ArgumentError(
        "sampled-lag reference interval must be positive",
    ))
    minimum <= maximum || throw(ArgumentError(
        "sampled-lag reference output bounds are reversed",
    ))
    exact_decay = exp(-interval / time_constant)
    next_state = exact_decay * state + (1.0 - exact_decay) * input
    return (
        state = next_state,
        output = clamp(gain_value * next_state, minimum, maximum),
        decay = exact_decay,
    )
end

"""Evaluate an independent passive cubic branch current, derivative, terminal power, and KCL residual."""
function passive_cubic_branch_reference(
    positive_voltage_v::Real,
    negative_voltage_v::Real,
    linear_conductance_s::Real,
    cubic_coefficient_a_per_v3::Real,
)
    positive_voltage, negative_voltage, conductance, cubic = Float64.((
        positive_voltage_v,
        negative_voltage_v,
        linear_conductance_s,
        cubic_coefficient_a_per_v3,
    ))
    all(isfinite, (positive_voltage, negative_voltage, conductance, cubic)) ||
        throw(ArgumentError("cubic-branch reference inputs must be finite"))
    conductance >= 0.0 && cubic >= 0.0 && (conductance > 0.0 || cubic > 0.0) ||
        throw(ArgumentError(
            "cubic-branch reference coefficients must be passive and not both zero",
        ))
    voltage = positive_voltage - negative_voltage
    current = muladd(cubic * voltage * voltage, voltage, conductance * voltage)
    derivative = conductance + 3.0 * cubic * voltage * voltage
    return (
        voltage_v = voltage,
        positive_current_a = current,
        negative_current_a = -current,
        derivative_s = derivative,
        absorbed_power_w = voltage * current,
        terminal_kcl_residual_a = current - current,
    )
end

"""Evaluate the independent trapezoidal series R-L recurrence without mutating accepted state."""
function series_rl_trapezoidal_reference(
    previous_current_a::Real,
    previous_voltage_v::Real,
    trial_voltage_v::Real,
    resistance_ohm::Real,
    inductance_h::Real,
    step_s::Real,
)
    previous_current, previous_voltage, trial_voltage, resistance, inductance, step = Float64.((
        previous_current_a,
        previous_voltage_v,
        trial_voltage_v,
        resistance_ohm,
        inductance_h,
        step_s,
    ))
    all(isfinite, (
        previous_current,
        previous_voltage,
        trial_voltage,
        resistance,
        inductance,
        step,
    )) || throw(ArgumentError("series R-L trapezoidal reference inputs must be finite"))
    resistance >= 0.0 || throw(ArgumentError(
        "series R-L reference resistance must be nonnegative",
    ))
    inductance > 0.0 || throw(ArgumentError(
        "series R-L reference inductance must be positive",
    ))
    step > 0.0 || throw(ArgumentError(
        "series R-L reference timestep must be positive",
    ))
    inductive_resistance = 2.0 * inductance / step
    conductance = inv(resistance + inductive_resistance)
    history_current = conductance * (
        previous_voltage + (inductive_resistance - resistance) * previous_current
    )
    trial_current = conductance * trial_voltage + history_current
    constitutive_residual =
        0.5 * (previous_voltage + trial_voltage) -
        resistance * 0.5 * (previous_current + trial_current) -
        inductance * (trial_current - previous_current) / step
    return (
        conductance_s = conductance,
        history_current_a = history_current,
        current_a = trial_current,
        constitutive_residual_v = constitutive_residual,
        stored_energy_j = 0.5 * inductance * trial_current^2,
        dissipated_power_w = resistance * trial_current^2,
    )
end

"""Locate a directed zero of a linearly interpolated event indicator on one accepted bracket."""
function directed_linear_event_root_reference(
    left_time_s::Real,
    right_time_s::Real,
    left_indicator::Real,
    right_indicator::Real;
    direction::Symbol = :any,
)
    left_time, right_time, left_value, right_value = Float64.((
        left_time_s,
        right_time_s,
        left_indicator,
        right_indicator,
    ))
    all(isfinite, (left_time, right_time, left_value, right_value)) || throw(
        ArgumentError("event-root reference inputs must be finite"),
    )
    right_time > left_time || throw(ArgumentError(
        "event-root reference requires a forward time bracket",
    ))
    direction in (:any, :rising, :falling) || throw(ArgumentError(
        "event-root reference direction is unsupported",
    ))
    crossed = left_value == 0.0 || right_value == 0.0 || signbit(left_value) != signbit(right_value)
    crossed || throw(ArgumentError("event-root reference bracket contains no zero"))
    direction === :rising && !(left_value <= 0.0 <= right_value) && throw(ArgumentError(
        "event-root reference bracket is not a rising crossing",
    ))
    direction === :falling && !(left_value >= 0.0 >= right_value) && throw(ArgumentError(
        "event-root reference bracket is not a falling crossing",
    ))
    left_value == 0.0 && return left_time
    right_value == 0.0 && return right_time
    fraction = -left_value / (right_value - left_value)
    return left_time + fraction * (right_time - left_time)
end

include("consistent_emt_initialization.jl")
include("general_multirate_task_reference.jl")
include("portable_hybrid_snapshot_reference.jl")
include("measurement_chains.jl")

end
