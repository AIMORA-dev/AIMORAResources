"""Independent immutable circuit graph used only for public bridge-topology checks."""
struct IndependentBridgeTopology
    family::Symbol
    node_names::Vector{Symbol}
    node_indices::Vector{Int}
    branch_names::Vector{Symbol}
    from_nodes::Vector{Int}
    to_nodes::Vector{Int}
    state_group_positions::Vector{Vector{Int}}
    state_group_tables::Vector{BitMatrix}

    function IndependentBridgeTopology(
        family::Symbol,
        node_names,
        node_indices,
        branch_names,
        from_nodes,
        to_nodes;
        state_group_positions=Vector{Int}[],
        state_group_tables=BitMatrix[],
    )
        names = Symbol.(node_names)
        nodes = Int.(node_indices)
        branches = Symbol.(branch_names)
        from = Int.(from_nodes)
        to = Int.(to_nodes)
        length(names) == length(nodes) && length(unique(names)) == length(names) ||
            throw(ArgumentError("independent bridge nodes require unique names and indices"))
        length(branches) == length(from) == length(to) && !isempty(branches) ||
            throw(DimensionMismatch("independent bridge branch arrays must have equal nonzero length"))
        length(unique(branches)) == length(branches) || throw(ArgumentError(
            "independent bridge branch names must be unique",
        ))
        all(index -> index in nodes, from) && all(index -> index in nodes, to) ||
            throw(ArgumentError("independent bridge branches must connect declared nodes"))
        all(from .!= to) || throw(ArgumentError(
            "independent bridge branches require distinct oriented terminals",
        ))
        positions = [Int.(group) for group in state_group_positions]
        tables = BitMatrix.(state_group_tables)
        length(positions) == length(tables) || throw(DimensionMismatch(
            "independent bridge state groups and tables must have equal length",
        ))
        all(zip(positions, tables)) do (group, table)
            size(table, 1) == length(group) && all(index -> 1 <= index <= length(branches), group)
        end || throw(DimensionMismatch("independent bridge state table has invalid rows"))
        return new(family, names, nodes, branches, from, to, positions, tables)
    end
end

function _independent_rectifier_graph(ac_nodes, dc_positive, dc_negative, mode)
    names = Symbol[:dc_positive]
    append!(names, [Symbol(:ac_, phase) for phase in eachindex(ac_nodes)])
    push!(names, :dc_negative)
    nodes = Int[dc_positive, ac_nodes..., dc_negative]
    branches = Symbol[]
    from = Int[]
    to = Int[]
    for (phase, ac_node) in enumerate(ac_nodes)
        push!(branches, Symbol(:phase_, phase, :_upper), Symbol(:phase_, phase, :_lower))
        if mode === :self_commutated
            push!(from, dc_positive, ac_node)
            push!(to, ac_node, dc_negative)
        else
            push!(from, ac_node, dc_negative)
            push!(to, dc_positive, ac_node)
        end
    end
    return names, nodes, branches, from, to
end

function _independent_complementary_groups(phase_count)
    positions = [[2phase - 1, 2phase] for phase in 1:phase_count]
    tables = [BitMatrix(Bool[1 0 0; 0 1 0]) for _ in 1:phase_count]
    return positions, tables
end

"""Construct a released bridge graph directly from published circuit definitions, independent of AIMORA production types."""
function independent_bridge_topology(family::Symbol; parameters...)
    if family in (:single_phase_graetz, :polyphase_bridge, :two_level_bridge, :full_bridge,
        :bidirectional_chopper)
        ac_nodes = Int.(get(parameters, :ac_nodes, family === :single_phase_graetz ||
            family === :full_bridge ? [1, 2] : [1]))
        dc_positive = Int(get(parameters, :dc_positive, maximum(ac_nodes) + 1))
        dc_negative = Int(get(parameters, :dc_negative, 0))
        mode = family in (:two_level_bridge, :full_bridge, :bidirectional_chopper) ?
            :self_commutated : Symbol(get(parameters, :mode, :diode))
        names, nodes, branches, from, to =
            _independent_rectifier_graph(ac_nodes, dc_positive, dc_negative, mode)
        positions, tables = mode === :self_commutated ?
            _independent_complementary_groups(length(ac_nodes)) : (Vector{Int}[], BitMatrix[])
        return IndependentBridgeTopology(
            family, names, nodes, branches, from, to;
            state_group_positions=positions,
            state_group_tables=tables,
        )
    elseif family === :step_down_chopper
        nodes = Int.(get(parameters, :nodes, [3, 1, 0]))
        return IndependentBridgeTopology(
            family,
            [:dc_positive, :output, :dc_negative],
            nodes,
            [:controlled, :freewheel],
            [nodes[1], nodes[3]],
            [nodes[2], nodes[2]];
            state_group_positions=[[1]],
            state_group_tables=[BitMatrix(Bool[1 0])],
        )
    elseif family === :step_up_chopper
        nodes = Int.(get(parameters, :nodes, [1, 3, 0]))
        return IndependentBridgeTopology(
            family,
            [:input_positive, :output_positive, :dc_negative],
            nodes,
            [:controlled, :boost_diode],
            [nodes[1], nodes[1]],
            [nodes[3], nodes[2]];
            state_group_positions=[[1]],
            state_group_tables=[BitMatrix(Bool[1 0])],
        )
    elseif family === :neutral_point_clamped_leg
        nodes = Int.(get(parameters, :nodes, [5, 3, 1, 0, 4, 2]))
        return IndependentBridgeTopology(
            family,
            [:dc_positive, :midpoint, :ac_terminal, :dc_negative,
                :upper_clamp_node, :lower_clamp_node],
            nodes,
            [:outer_upper, :inner_upper, :inner_lower, :outer_lower,
                :upper_clamp, :lower_clamp],
            [nodes[1], nodes[5], nodes[3], nodes[6], nodes[2], nodes[6]],
            [nodes[5], nodes[3], nodes[6], nodes[4], nodes[5], nodes[2]];
            state_group_positions=[collect(1:4)],
            state_group_tables=[BitMatrix(Bool[
                1 0 0 0;
                1 1 0 0;
                0 1 1 0;
                0 0 1 0;
            ])],
        )
    elseif family === :t_type_leg
        nodes = Int.(get(parameters, :nodes, [4, 2, 1, 0, 3]))
        return IndependentBridgeTopology(
            family,
            [:dc_positive, :midpoint, :ac_terminal, :dc_negative, :midpoint_path_node],
            nodes,
            [:outer_upper, :midpoint_ac_side, :midpoint_dc_side, :outer_lower],
            [nodes[1], nodes[3], nodes[5], nodes[3]],
            [nodes[3], nodes[5], nodes[2], nodes[4]];
            state_group_positions=[collect(1:4)],
            state_group_tables=[BitMatrix(Bool[
                1 0 0 0;
                0 1 0 0;
                0 1 0 0;
                0 0 1 0;
            ])],
        )
    elseif family === :flying_capacitor_leg
        nodes = Int.(get(parameters, :nodes, [4, 1, 0, 3, 2]))
        return IndependentBridgeTopology(
            family,
            [:dc_positive, :ac_terminal, :dc_negative, :upper_flying_node,
                :lower_flying_node],
            nodes,
            [:outer_upper, :inner_upper, :inner_lower, :outer_lower, :flying_capacitor],
            [nodes[1], nodes[4], nodes[2], nodes[5], nodes[4]],
            [nodes[4], nodes[2], nodes[5], nodes[3], nodes[5]];
            state_group_positions=[collect(1:4)],
            state_group_tables=[BitMatrix(Bool[
                1 1 0 0 0;
                1 0 1 0 0;
                0 1 0 1 0;
                0 0 1 1 0;
            ])],
        )
    elseif family === :cascaded_h_bridge_phase
        cell_count = Int(get(parameters, :cell_count, 2))
        1 <= cell_count <= 16 || throw(ArgumentError(
            "independent cascaded H-bridge requires one through sixteen cells",
        ))
        phase_positive = Int(get(parameters, :phase_positive, 1))
        phase_negative = Int(get(parameters, :phase_negative, 0))
        junctions = Int.(get(parameters, :series_junctions, collect(2:cell_count)))
        length(junctions) == cell_count - 1 || throw(ArgumentError(
            "independent cascaded H-bridge series junction count is invalid",
        ))
        dc_nodes = get(parameters, :cell_dc_nodes,
            [(100 + 2cell, 101 + 2cell) for cell in 1:cell_count])
        series_nodes = Int[phase_positive, junctions..., phase_negative]
        names = Symbol[:phase_positive, :phase_negative]
        nodes = Int[phase_positive, phase_negative]
        append!(names, [Symbol(:series_junction_, index) for index in eachindex(junctions)])
        append!(nodes, junctions)
        branches = Symbol[]
        from = Int[]
        to = Int[]
        groups = Vector{Int}[]
        tables = BitMatrix[]
        for cell in 1:cell_count
            dc_positive, dc_negative = Int.(dc_nodes[cell])
            push!(names, Symbol(:cell_, cell, :_dc_positive), Symbol(:cell_, cell, :_dc_negative))
            push!(nodes, dc_positive, dc_negative)
            left, right = series_nodes[cell], series_nodes[cell + 1]
            first_position = length(branches) + 1
            append!(branches, [Symbol(:cell_, cell, :_left_upper),
                Symbol(:cell_, cell, :_left_lower), Symbol(:cell_, cell, :_right_upper),
                Symbol(:cell_, cell, :_right_lower)])
            append!(from, [dc_positive, left, dc_positive, right])
            append!(to, [left, dc_negative, right, dc_negative])
            push!(groups, collect(first_position:(first_position + 3)))
            push!(tables, BitMatrix(Bool[
                1 0 1 0 0;
                0 1 0 1 0;
                1 0 0 1 0;
                0 1 1 0 0;
            ]))
        end
        return IndependentBridgeTopology(family, names, nodes, branches, from, to;
            state_group_positions=groups, state_group_tables=tables)
    end
    throw(ArgumentError("unsupported independent bridge topology family $family"))
end

"""Return direct +1/-1 branch incidence without production bridge or stamp reuse."""
function independent_bridge_incidence(topology::IndependentBridgeTopology)
    node_order = unique(topology.node_indices)
    lookup = Dict(node => index for (index, node) in enumerate(node_order))
    incidence = zeros(Int8, length(node_order), length(topology.branch_names))
    for branch in eachindex(topology.branch_names)
        incidence[lookup[topology.from_nodes[branch]], branch] = 1
        incidence[lookup[topology.to_nodes[branch]], branch] = -1
    end
    return (node_order=node_order, incidence=incidence)
end

function independent_bridge_kcl(
    topology::IndependentBridgeTopology,
    branch_current_a::AbstractVector{<:Real},
)
    length(branch_current_a) == length(topology.branch_names) || throw(DimensionMismatch(
        "independent bridge current vector must match branch count",
    ))
    return independent_bridge_incidence(topology).incidence * Float64.(branch_current_a)
end

function independent_bridge_terminal_power(
    topology::IndependentBridgeTopology,
    node_voltage_v::AbstractVector{<:Real},
    branch_current_a::AbstractVector{<:Real},
)
    incidence = independent_bridge_incidence(topology).incidence
    length(node_voltage_v) == size(incidence, 1) || throw(DimensionMismatch(
        "independent bridge voltage vector must match declared nodes",
    ))
    length(branch_current_a) == size(incidence, 2) || throw(DimensionMismatch(
        "independent bridge current vector must match branches",
    ))
    branch_voltage = transpose(incidence) * Float64.(node_voltage_v)
    return dot(branch_voltage, Float64.(branch_current_a))
end

function independent_bridge_state_is_allowed(
    topology::IndependentBridgeTopology,
    requested_state::AbstractVector{Bool},
)
    length(requested_state) == length(topology.branch_names) || throw(DimensionMismatch(
        "independent bridge state length must match branch count",
    ))
    return all(zip(topology.state_group_positions, topology.state_group_tables)) do (positions, table)
        state = requested_state[positions]
        any(column -> all(state .== view(table, :, column)), axes(table, 2))
    end
end

"""Direct passive backward-Euler recurrence for one oriented resistor, inductor, or capacitor."""
function independent_bridge_passive_backward_euler(
    kind::Symbol,
    voltage_v::Real,
    previous_current_a::Real,
    previous_voltage_v::Real,
    step_s::Real;
    resistance_ohm::Real=0.0,
    inductance_h::Real=0.0,
    capacitance_f::Real=0.0,
)
    voltage, previous_current, previous_voltage, step, resistance, inductance, capacitance =
        Float64.((voltage_v, previous_current_a, previous_voltage_v, step_s,
            resistance_ohm, inductance_h, capacitance_f))
    all(isfinite, (voltage, previous_current, previous_voltage, step, resistance,
        inductance, capacitance)) && step > 0.0 || throw(ArgumentError(
        "independent bridge passive inputs must be finite and timestep positive",
    ))
    current = if kind === :resistor
        resistance > 0.0 || throw(ArgumentError("independent resistor must be positive"))
        voltage / resistance
    elseif kind === :inductor
        inductance > 0.0 && resistance >= 0.0 || throw(ArgumentError(
            "independent inductor requires positive L and nonnegative R",
        ))
        (previous_current + step * voltage / inductance) /
            (1.0 + step * resistance / inductance)
    elseif kind === :capacitor
        capacitance > 0.0 || throw(ArgumentError("independent capacitor must be positive"))
        capacitance * (voltage - previous_voltage) / step
    else
        throw(ArgumentError("unsupported independent bridge passive kind $kind"))
    end
    charge = kind === :capacitor ? capacitance * voltage : 0.0
    flux = kind === :inductor ? inductance * current : 0.0
    loss = resistance * current^2
    stored_energy = 0.5 * (charge * voltage + flux * current)
    return (; current_a=current, charge_c=charge, flux_wb=flux,
        dissipated_power_w=loss, stored_energy_j=stored_energy)
end

function independent_cascaded_h_bridge_voltage(
    cell_dc_voltage_v::AbstractVector{<:Real},
    cell_state::AbstractVector{<:Integer},
)
    length(cell_dc_voltage_v) == length(cell_state) || throw(DimensionMismatch(
        "cascaded H-bridge voltages and states must have equal length",
    ))
    all(state -> state in (-1, 0, 1), cell_state) || throw(ArgumentError(
        "cascaded H-bridge state must be -1, 0, or 1",
    ))
    return dot(Float64.(cell_dc_voltage_v), Int.(cell_state))
end
