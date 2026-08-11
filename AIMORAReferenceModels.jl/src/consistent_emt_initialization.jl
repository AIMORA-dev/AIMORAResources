"""Independent dense harmonic solution and strict numerical/topological diagnostics for a passive network."""
struct IndependentHarmonicNetworkResult
    node_voltage_phasors::Vector{ComplexF64}
    source_injection_phasors::Vector{ComplexF64}
    numerical_rank::Int
    condition_estimate::Float64
    maximum_residual_a::Float64
    relative_residual::Float64
    connected_components::Vector{Vector{Int}}
    referenced_components::BitVector
    unreferenced_components::Vector{Vector{Int}}
    classification::Symbol
    admittance_symmetry_max_abs_error::Float64
    minimum_dissipative_eigenvalue_s::Float64
end

"""Evaluate the bilinear/trapezoidal reactive angular frequency while retaining the physical waveform frequency."""
function trapezoidal_reactive_angular_frequency(
    physical_frequency_hz::Real,
    timestep_s::Real,
)
    frequency = Float64(physical_frequency_hz)
    timestep = Float64(timestep_s)
    isfinite(frequency) && frequency >= 0.0 || throw(ArgumentError(
        "physical frequency must be finite and nonnegative",
    ))
    isfinite(timestep) && timestep > 0.0 || throw(ArgumentError(
        "timestep must be finite and positive",
    ))
    angle = pi * frequency * timestep
    angle < 0.5 * pi || throw(ArgumentError(
        "trapezoidal harmonic evaluation must remain below Nyquist",
    ))
    return 2.0 / timestep * tan(angle)
end

function _independent_complex_branch_stamp!(
    admittance::Matrix{ComplexF64},
    from_node::Int,
    to_node::Int,
    branch_admittance::ComplexF64,
)
    from_node != 0 && (admittance[from_node, from_node] += branch_admittance)
    to_node != 0 && (admittance[to_node, to_node] += branch_admittance)
    if from_node != 0 && to_node != 0
        admittance[from_node, to_node] -= branch_admittance
        admittance[to_node, from_node] -= branch_admittance
    end
    return admittance
end

function _independent_harmonic_components(
    admittance::Matrix{ComplexF64},
    threshold::Float64,
)
    node_count = size(admittance, 1)
    unseen = trues(node_count)
    components = Vector{Vector{Int}}()
    for first_node in 1:node_count
        unseen[first_node] || continue
        unseen[first_node] = false
        component = Int[]
        pending = Int[first_node]
        while !isempty(pending)
            node = popfirst!(pending)
            push!(component, node)
            for neighbor in 1:node_count
                unseen[neighbor] || continue
                neighbor == node && continue
                if abs(admittance[node, neighbor]) > threshold ||
                   abs(admittance[neighbor, node]) > threshold
                    unseen[neighbor] = false
                    push!(pending, neighbor)
                end
            end
        end
        push!(components, sort!(component))
    end
    return components
end

function _independent_dense_harmonic_solution(
    admittance::Matrix{ComplexF64},
    source_injection::Vector{ComplexF64};
    absolute_current_tolerance_a::Float64,
    relative_current_tolerance::Float64,
    rank_threshold_multiplier::Float64,
    maximum_condition_estimate::Float64,
)
    node_count = length(source_injection)
    size(admittance) == (node_count, node_count) || throw(DimensionMismatch(
        "independent admittance dimensions must match source injections",
    ))
    matrix_scale = maximum(abs, admittance; init=0.0)
    structural_threshold = max(
        node_count * eps(Float64) * rank_threshold_multiplier * matrix_scale,
        floatmin(Float64),
    )
    components = _independent_harmonic_components(
        admittance,
        structural_threshold,
    )
    referenced = BitVector(
        any(
            node -> abs(sum(admittance[node, :])) > structural_threshold,
            component,
        )
        for component in components
    )
    unreferenced = Vector{Int}[
        copy(component)
        for (component, has_reference) in zip(components, referenced)
        if !has_reference
    ]
    row_scale = Float64[
        sqrt(max(
            sum(abs, admittance[node, :]),
            sum(abs, admittance[:, node]),
            structural_threshold,
        ))
        for node in 1:node_count
    ]
    scaled = admittance ./ (row_scale * transpose(row_scale))
    decomposition = svd(scaled)
    largest = maximum(decomposition.S; init=0.0)
    rank_threshold = node_count * eps(Float64) *
        rank_threshold_multiplier * largest
    numerical_rank = count(value -> value > rank_threshold, decomposition.S)
    condition_estimate = numerical_rank == node_count ?
        largest / minimum(decomposition.S) : Inf
    candidate = numerical_rank == node_count ?
        admittance \ source_injection :
        decomposition \ (source_injection ./ row_scale) ./ row_scale
    residual = admittance * candidate - source_injection
    maximum_residual = norm(residual, Inf)
    source_scale = max(norm(source_injection, Inf), absolute_current_tolerance_a)
    relative_residual = maximum_residual / source_scale
    allowance = absolute_current_tolerance_a +
        relative_current_tolerance * norm(source_injection, Inf)
    classification = if maximum_residual > allowance
        :infeasible
    elseif numerical_rank < node_count
        isempty(unreferenced) ? :nonunique : :islanded
    elseif condition_estimate > maximum_condition_estimate
        :ill_conditioned
    else
        :unique
    end
    solution = classification === :unique ? ComplexF64.(candidate) : ComplexF64[]
    symmetry_error = maximum(
        abs,
        admittance - transpose(admittance);
        init=0.0,
    )
    dissipative = Hermitian(0.5 .* (admittance + adjoint(admittance)))
    minimum_dissipative_eigenvalue = minimum(eigvals(dissipative); init=0.0)
    return IndependentHarmonicNetworkResult(
        solution,
        copy(source_injection),
        numerical_rank,
        condition_estimate,
        maximum_residual,
        relative_residual,
        components,
        referenced,
        unreferenced,
        classification,
        symmetry_error,
        minimum_dissipative_eigenvalue,
    )
end

"""Independently assemble and solve a dense network of series R-L branches, shunt conductances, and finite-conductance voltage sources."""
function independent_series_rl_network_equilibrium(
    node_count::Integer,
    series_branches,
    shunt_conductances,
    voltage_sources;
    physical_frequency_hz::Real,
    timestep_s::Union{Nothing,Real}=nothing,
    time_origin_s::Real=0.0,
    absolute_current_tolerance_a::Real=1.0e-10,
    relative_current_tolerance::Real=1.0e-10,
    rank_threshold_multiplier::Real=10.0,
    maximum_condition_estimate::Real=1.0e12,
)
    nodes = Int(node_count)
    nodes > 0 || throw(ArgumentError("independent network requires at least one node"))
    frequency = Float64(physical_frequency_hz)
    time_origin = Float64(time_origin_s)
    isfinite(frequency) && frequency >= 0.0 || throw(ArgumentError(
        "independent network frequency must be finite and nonnegative",
    ))
    isfinite(time_origin) || throw(ArgumentError(
        "independent network time origin must be finite",
    ))
    reactive_angular_frequency = timestep_s === nothing ?
        2.0 * pi * frequency :
        trapezoidal_reactive_angular_frequency(frequency, timestep_s)
    admittance = zeros(ComplexF64, nodes, nodes)
    source_injection = zeros(ComplexF64, nodes)
    for branch in series_branches
        from_node = Int(branch.from_node)
        to_node = Int(branch.to_node)
        resistance = Float64(branch.resistance_ohm)
        inductance = Float64(branch.inductance_h)
        0 <= from_node <= nodes && 0 <= to_node <= nodes &&
            from_node != to_node || throw(ArgumentError(
            "independent series R-L branch terminals are invalid",
        ))
        resistance >= 0.0 && inductance >= 0.0 &&
            resistance + inductance > 0.0 || throw(ArgumentError(
            "independent series R-L parameters are invalid",
        ))
        impedance = complex(
            resistance,
            reactive_angular_frequency * inductance,
        )
        _independent_complex_branch_stamp!(
            admittance,
            from_node,
            to_node,
            inv(impedance),
        )
    end
    for shunt in shunt_conductances
        node = Int(shunt.node)
        conductance = Float64(shunt.conductance_s)
        1 <= node <= nodes && isfinite(conductance) && conductance > 0.0 ||
            throw(ArgumentError("independent shunt conductance is invalid"))
        admittance[node, node] += conductance
    end
    for source in voltage_sources
        node = Int(source.node)
        conductance = Float64(source.conductance_s)
        voltage = ComplexF64(source.voltage_phasor_v)
        1 <= node <= nodes && isfinite(conductance) && conductance > 0.0 ||
            throw(ArgumentError("independent voltage source is invalid"))
        all(isfinite, (real(voltage), imag(voltage))) || throw(ArgumentError(
            "independent voltage-source phasor must be finite",
        ))
        admittance[node, node] += conductance
        source_injection[node] += conductance * voltage
    end
    rotation = cis(2.0 * pi * frequency * time_origin)
    result = _independent_dense_harmonic_solution(
        admittance,
        source_injection;
        absolute_current_tolerance_a=Float64(absolute_current_tolerance_a),
        relative_current_tolerance=Float64(relative_current_tolerance),
        rank_threshold_multiplier=Float64(rank_threshold_multiplier),
        maximum_condition_estimate=Float64(maximum_condition_estimate),
    )
    return IndependentHarmonicNetworkResult(
        result.node_voltage_phasors .* rotation,
        result.source_injection_phasors .* rotation,
        result.numerical_rank,
        result.condition_estimate,
        result.maximum_residual_a,
        result.relative_residual,
        result.connected_components,
        result.referenced_components,
        result.unreferenced_components,
        result.classification,
        result.admittance_symmetry_max_abs_error,
        result.minimum_dissipative_eigenvalue_s,
    )
end

"""Return physical-time samples from a peak phasor without RMS, phase, or orientation inference."""
function independent_peak_phasor_samples(
    peak_phasor,
    physical_frequency_hz::Real,
    sample_times_s,
)
    phasor = ComplexF64(peak_phasor)
    frequency = Float64(physical_frequency_hz)
    times = Float64.(sample_times_s)
    all(isfinite, (real(phasor), imag(phasor), frequency)) &&
        frequency >= 0.0 && all(isfinite, times) || throw(ArgumentError(
        "independent phasor sampling inputs must be finite and nonnegative in frequency",
    ))
    return Float64[
        real(phasor * cis(2.0 * pi * frequency * time_s))
        for time_s in times
    ]
end

"""Independently evaluate the first-step trapezoidal recurrence residual for every declared series R-L branch."""
function independent_series_rl_recurrence_residuals(
    node_voltage_phasors,
    series_branches;
    physical_frequency_hz::Real,
    timestep_s::Real,
)
    voltages = ComplexF64.(node_voltage_phasors)
    frequency = Float64(physical_frequency_hz)
    timestep = Float64(timestep_s)
    reactive_angular_frequency =
        trapezoidal_reactive_angular_frequency(frequency, timestep)
    advance = cis(2.0 * pi * frequency * timestep)
    residuals = Float64[]
    for branch in series_branches
        from_node = Int(branch.from_node)
        to_node = Int(branch.to_node)
        voltage_phasor =
            (from_node == 0 ? 0.0 + 0.0im : voltages[from_node]) -
            (to_node == 0 ? 0.0 + 0.0im : voltages[to_node])
        resistance = Float64(branch.resistance_ohm)
        inductance = Float64(branch.inductance_h)
        current_phasor = voltage_phasor /
            complex(resistance, reactive_angular_frequency * inductance)
        conductance = inv(resistance + 2.0 * inductance / timestep)
        history_current = conductance * (
            real(voltage_phasor) +
            (2.0 * inductance / timestep - resistance) * real(current_phasor)
        )
        predicted = conductance * real(voltage_phasor * advance) + history_current
        push!(residuals, predicted - real(current_phasor * advance))
    end
    return residuals
end

"""Independently construct one periodic scalar trapezoidal R-L, series R-L-C, or capacitor state and its first-step residual."""
function independent_lumped_companion_periodic_state(
    branch_kind::Symbol,
    voltage_peak_phasor;
    resistance_ohm::Real=0.0,
    inductance_h::Real=0.0,
    capacitance_f::Real=0.0,
    physical_frequency_hz::Real,
    timestep_s::Real,
)
    branch_kind in (:series_rl, :series_rlc, :capacitor) || throw(ArgumentError(
        "independent lumped recurrence requires :series_rl, :series_rlc, or :capacitor",
    ))
    voltage = ComplexF64(voltage_peak_phasor)
    resistance = Float64(resistance_ohm)
    inductance = Float64(inductance_h)
    capacitance = Float64(capacitance_f)
    frequency = Float64(physical_frequency_hz)
    timestep = Float64(timestep_s)
    all(isfinite, (
        real(voltage),
        imag(voltage),
        resistance,
        inductance,
        capacitance,
        frequency,
        timestep,
    )) || throw(ArgumentError("independent lumped recurrence inputs must be finite"))
    resistance >= 0.0 || throw(ArgumentError("resistance must be nonnegative"))
    inductance >= 0.0 || throw(ArgumentError("inductance must be nonnegative"))
    frequency > 0.0 || throw(ArgumentError("physical frequency must be positive"))
    timestep > 0.0 || throw(ArgumentError("timestep must be positive"))
    branch_kind === :series_rlc && capacitance <= 0.0 && throw(ArgumentError(
        "series R-L-C capacitance must be positive",
    ))
    branch_kind === :capacitor && capacitance <= 0.0 && throw(ArgumentError(
        "capacitor capacitance must be positive",
    ))
    reactive_angular_frequency =
        trapezoidal_reactive_angular_frequency(frequency, timestep)
    advance = cis(2.0 * pi * frequency * timestep)
    next_voltage = real(voltage * advance)
    if branch_kind === :series_rl
        resistance + inductance > 0.0 || throw(ArgumentError(
            "series R-L impedance must be nonzero",
        ))
        current = voltage /
            complex(resistance, reactive_angular_frequency * inductance)
        conductance = inv(resistance + 2.0 * inductance / timestep)
        history_current = conductance * (
            real(voltage) +
            (2.0 * inductance / timestep - resistance) * real(current)
        )
        expected_next_current = real(current * advance)
        return (
            current_peak_phasor_a=current,
            previous_voltage_v=real(voltage),
            previous_current_a=real(current),
            previous_inductor_voltage_v=0.0,
            previous_capacitor_voltage_v=0.0,
            next_voltage_v=next_voltage,
            expected_next_current_a=expected_next_current,
            companion_conductance_s=conductance,
            companion_history_current_a=history_current,
            recurrence_residual_a=
                conductance * next_voltage + history_current -
                expected_next_current,
        )
    elseif branch_kind === :series_rlc
        impedance = complex(
            resistance,
            reactive_angular_frequency * inductance -
                inv(reactive_angular_frequency * capacitance),
        )
        abs(impedance) > 0.0 || throw(ArgumentError(
            "series R-L-C harmonic impedance must be nonzero",
        ))
        current = voltage / impedance
        inductor_voltage =
            im * reactive_angular_frequency * inductance * current
        capacitor_voltage =
            current / (im * reactive_angular_frequency * capacitance)
        inductive_resistance = 2.0 * inductance / timestep
        capacitive_resistance = timestep / (2.0 * capacitance)
        conductance = inv(
            resistance + inductive_resistance + capacitive_resistance,
        )
        history_current = conductance * (
            (inductive_resistance - capacitive_resistance) * real(current) +
            real(inductor_voltage) - real(capacitor_voltage)
        )
        expected_next_current = real(current * advance)
        return (
            current_peak_phasor_a=current,
            previous_voltage_v=real(voltage),
            previous_current_a=real(current),
            previous_inductor_voltage_v=real(inductor_voltage),
            previous_capacitor_voltage_v=real(capacitor_voltage),
            next_voltage_v=next_voltage,
            expected_next_current_a=expected_next_current,
            companion_conductance_s=conductance,
            companion_history_current_a=history_current,
            recurrence_residual_a=
                conductance * next_voltage + history_current -
                expected_next_current,
        )
    end
    current = im * reactive_angular_frequency * capacitance * voltage
    conductance = 2.0 * capacitance / timestep
    history_current = -conductance * real(voltage) - real(current)
    expected_next_current = real(current * advance)
    return (
        current_peak_phasor_a=current,
        previous_voltage_v=real(voltage),
        previous_current_a=real(current),
        previous_inductor_voltage_v=0.0,
        previous_capacitor_voltage_v=real(voltage),
        next_voltage_v=next_voltage,
        expected_next_current_a=expected_next_current,
        companion_conductance_s=conductance,
        companion_history_current_a=history_current,
        recurrence_residual_a=
            conductance * next_voltage + history_current -
            expected_next_current,
    )
end

"""Return the independent scalar first-step recurrence residual for a periodic lumped companion state."""
function independent_lumped_companion_recurrence_residual(args...; kwargs...)
    return independent_lumped_companion_periodic_state(
        args...;
        kwargs...,
    ).recurrence_residual_a
end

"""Independently construct the periodic first-step trapezoidal state of a coupled series R-L multiport."""
function independent_coupled_series_rl_periodic_state(
    port_voltage_peak_phasors,
    resistance_matrix,
    inductance_matrix;
    physical_frequency_hz::Real,
    timestep_s::Real,
)
    voltage = ComplexF64.(port_voltage_peak_phasors)
    resistance = Float64.(resistance_matrix)
    inductance = Float64.(inductance_matrix)
    port_count = length(voltage)
    size(resistance) == (port_count, port_count) || throw(DimensionMismatch(
        "coupled resistance matrix must match the port count",
    ))
    size(inductance) == size(resistance) || throw(DimensionMismatch(
        "coupled inductance matrix must match resistance",
    ))
    all(isfinite, resistance) && all(isfinite, inductance) &&
        all(value -> isfinite(real(value)) && isfinite(imag(value)), voltage) ||
        throw(ArgumentError("coupled recurrence inputs must be finite"))
    frequency = Float64(physical_frequency_hz)
    timestep = Float64(timestep_s)
    reactive_angular_frequency =
        trapezoidal_reactive_angular_frequency(frequency, timestep)
    harmonic_impedance = complex.(
        resistance,
        reactive_angular_frequency .* inductance,
    )
    current = harmonic_impedance \ voltage
    companion_impedance = resistance .+ (2.0 / timestep) .* inductance
    conductance = companion_impedance \ Matrix{Float64}(I, port_count, port_count)
    history_current = conductance * (
        real.(voltage) .+
        ((2.0 / timestep) .* inductance .- resistance) * real.(current)
    )
    advance = cis(2.0 * pi * frequency * timestep)
    predicted_current = conductance * real.(voltage .* advance) + history_current
    expected_next_current = real.(current .* advance)
    return (
        current_peak_phasors_a=current,
        previous_voltage_v=real.(voltage),
        previous_current_a=real.(current),
        next_voltage_v=real.(voltage .* advance),
        expected_next_current_a=expected_next_current,
        companion_conductance_s=conductance,
        companion_history_current_a=history_current,
        recurrence_residual_a=predicted_current - expected_next_current,
    )
end

"""Return independent first-step trapezoidal recurrence residuals for a coupled series R-L multiport."""
function independent_coupled_series_rl_recurrence_residuals(args...; kwargs...)
    return independent_coupled_series_rl_periodic_state(
        args...;
        kwargs...,
    ).recurrence_residual_a
end

"""Compare a voltage trace with independently sampled per-node peak phasors and physical frequencies."""
function independent_periodic_voltage_error(
    node_voltage_peak_phasors,
    node_physical_frequencies_hz,
    sample_times_s,
    actual_voltage_v,
)
    phasors = ComplexF64.(node_voltage_peak_phasors)
    frequencies = Float64.(node_physical_frequencies_hz)
    times = Float64.(sample_times_s)
    actual = Float64.(actual_voltage_v)
    length(phasors) == length(frequencies) || throw(DimensionMismatch(
        "periodic voltage phasors and frequencies must align",
    ))
    size(actual) == (length(phasors), length(times)) || throw(DimensionMismatch(
        "actual periodic voltage trace dimensions are inconsistent",
    ))
    all(isfinite, frequencies) && all(>=(0.0), frequencies) &&
        all(isfinite, times) && all(isfinite, actual) || throw(ArgumentError(
        "periodic voltage trace inputs must be finite with nonnegative frequencies",
    ))
    expected = Matrix{Float64}(undef, length(phasors), length(times))
    for sample_index in eachindex(times), node_index in eachindex(phasors)
        expected[node_index, sample_index] = real(
            phasors[node_index] *
            cis(2.0 * pi * frequencies[node_index] * times[sample_index]),
        )
    end
    error = actual - expected
    reference_norm = max(norm(expected), eps(Float64))
    reference_peak = max(maximum(abs, expected; init=0.0), eps(Float64))
    return (
        expected_voltage_v=expected,
        error_voltage_v=error,
        maximum_absolute_error_v=maximum(abs, error; init=0.0),
        normalized_rms=norm(error) / reference_norm,
        maximum_scaled_error=maximum(abs, error; init=0.0) / reference_peak,
    )
end

"""Apply one explicit complex-valued scale and orientation mapping and report its absolute residual against a target."""
function independent_operating_point_mapping(
    source_value,
    target_value;
    scale_to_target::Real,
    orientation_sign::Real,
)
    source = ComplexF64(source_value)
    target = ComplexF64(target_value)
    scale = Float64(scale_to_target)
    sign = Float64(orientation_sign)
    isfinite(scale) && scale > 0.0 || throw(ArgumentError(
        "independent mapping scale must be finite and positive",
    ))
    sign in (-1.0, 1.0) || throw(ArgumentError(
        "independent mapping orientation sign must be -1 or 1",
    ))
    mapped = sign * scale * source
    return (mapped_value=mapped, residual=abs(mapped - target))
end
