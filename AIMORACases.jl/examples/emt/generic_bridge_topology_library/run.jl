#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.Branches
using AIMORA.Nodal
using AIMORA.Nonlinear
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal
using .ExampleSupport

const TOPOLOGIES = AIMORA.BridgeTopologies
const TIMESTEP_S = 10.0e-6
const SAMPLE_COUNT = 48
const CHECKPOINT_SAMPLE = 24

function public_bridge_valve(position; extended::Bool=false)
    if position.valve_class === :diode
        fidelity = extended ? PowerSemiconductorExtendedFidelity(
            junction_charge=NonlinearJunctionChargeFidelity(
                2.0e-9,
                100.0,
                0.4;
                voltage_domain_v=(-500.0, 500.0),
            ),
        ) : nothing
        return DiodeValveSwitch(
            position.from_node,
            position.to_node;
            on_conductance=5.0,
            off_conductance=1.0e-4,
            extended_fidelity=fidelity,
        )
    elseif position.valve_class === :thyristor
        return ThyristorValveSwitch(
            position.from_node,
            position.to_node;
            gate_driver=PowerSemiconductorGateDriver(),
            on_conductance=5.0,
            off_conductance=1.0e-4,
        )
    end
    return IGBTSwitch(
        position.from_node,
        position.to_node;
        gate_driver=PowerSemiconductorGateDriver(),
        antiparallel_diode=AntiparallelDiodeParameters(on_conductance_s=5.0),
        on_conductance=5.0,
        off_conductance=1.0e-4,
    )
end

function public_bridge_runtime(topology; extended_position::Int=0)
    valves = [
        public_bridge_valve(position; extended=index == extended_position)
        for (index, position) in enumerate(topology.valve_positions)
    ]
    passives = map(topology.passive_positions) do position
        position.kind === :capacitor && return CapacitorBranch(
            position.from_node,
            position.to_node,
            20.0e-6,
        )
        position.kind === :series_rl && return SeriesRLBranch(
            position.from_node,
            position.to_node,
            0.2,
            1.0e-3,
        )
        position.kind === :series_rlc && return SeriesRLCBranch(
            position.from_node,
            position.to_node,
            0.2,
            1.0e-3,
            20.0e-6,
        )
        ConductanceBranch(position.from_node, position.to_node, 0.01)
    end
    return PowerSemiconductorBridgeTopology(topology, valves; passives)
end

function public_bridge_topologies()
    return (
        diode=TOPOLOGIES.single_phase_graetz_topology((1, 2), 3, 0),
        thyristor=TOPOLOGIES.single_phase_graetz_topology(
            (4, 5), 6, 0; mode=:thyristor,
        ),
        full_bridge=TOPOLOGIES.full_bridge_topology(7, 8, 9, 0),
        step_down=TOPOLOGIES.step_down_chopper_topology(10, 11, 0),
        step_up=TOPOLOGIES.step_up_chopper_topology(12, 13, 0),
        bidirectional=TOPOLOGIES.bidirectional_chopper_topology(14, 15, 0),
        multigroup=TOPOLOGIES.multigroup_bridge_topology(
            [[16, 17, 18], [19, 20, 21]],
            [(22, 23), (23, 0)];
            composition=:series,
        ),
        npc=TOPOLOGIES.neutral_point_clamped_leg_topology(24, 25, 26, 0, 27, 28),
        t_type=TOPOLOGIES.t_type_leg_topology(29, 30, 31, 0, 32),
        flying=TOPOLOGIES.flying_capacitor_leg_topology(33, 34, 0, 35, 36),
        cascaded=TOPOLOGIES.cascaded_h_bridge_phase_topology(
            37, 0, [(39, 40), (41, 42)], [38],
        ),
    )
end

function public_bridge_network()
    topology = public_bridge_topologies()
    bridge = (
        diode=public_bridge_runtime(topology.diode; extended_position=1),
        thyristor=public_bridge_runtime(topology.thyristor),
        full_bridge=public_bridge_runtime(topology.full_bridge),
        step_down=public_bridge_runtime(topology.step_down),
        step_up=public_bridge_runtime(topology.step_up),
        bidirectional=public_bridge_runtime(topology.bidirectional),
        multigroup=public_bridge_runtime(topology.multigroup),
        npc=public_bridge_runtime(topology.npc),
        t_type=public_bridge_runtime(topology.t_type),
        flying=public_bridge_runtime(topology.flying),
        cascaded=public_bridge_runtime(topology.cascaded),
    )
    all_bridges = collect(values(bridge))
    external_nodes = sort!(unique(vcat((
        [node.node for node in runtime.topology.nodes if node.role === :external && node.node != 0]
        for runtime in all_bridges
    )...)))
    elements = Any[all_bridges...]
    for node in external_nodes
        push!(elements, ConductanceBranch(node, 0, 0.025 + 0.0005 * mod(node, 5)))
        push!(elements, CurrentInjection(
            node,
            time_s -> 0.25 * sin(2.0 * pi * 500.0 * time_s + 0.07 * node) +
                0.04 * cos(2.0 * pi * 250.0 * time_s + 0.03 * node),
        ))
    end
    linear_system = NodalSystem(42, elements)
    nonlinear_valves = vcat((
        collect(power_semiconductor_bridge_topology_nonlinear_valves(runtime))
        for runtime in all_bridges
    )...)
    system = NonlinearNodalSystem(
        linear_system,
        nonlinear_valves;
        scales=NonlinearNetworkScales(
            fill(100.0, 42),
            fill(10.0, 42),
            Float64[],
            Float64[],
        ),
    )
    return (; system, bridge, all_bridges)
end

function request_initial_states!(bridge)
    request_power_semiconductor_topology_gates!(
        bridge.thyristor, Bool[true, false, true, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.full_bridge, Bool[true, false, false, true], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.step_down, Bool[true, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.step_up, Bool[true, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.bidirectional, Bool[true, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.npc, Bool[true, true, false, false, false, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.t_type, Bool[true, false, false, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.flying, Bool[true, true, false, false], 0.0,
    )
    request_power_semiconductor_topology_gates!(
        bridge.cascaded,
        Bool[true, false, false, true, false, true, true, false],
        0.0,
    )
    return bridge
end

function apply_scheduled_operation!(bridge, sample::Int, time_s::Float64)
    if sample == 12
        block_power_semiconductor_topology!(bridge.full_bridge, time_s)
    elseif sample == 16
        restart_power_semiconductor_topology!(bridge.full_bridge, time_s)
        request_power_semiconductor_topology_gates!(
            bridge.full_bridge, Bool[false, true, true, false], time_s,
        )
    elseif sample == 20
        apply_power_semiconductor_topology_fault!(
            bridge.step_down,
            :controlled,
            BRIDGE_POSITION_STUCK_OPEN,
            time_s,
        )
    elseif sample == 24
        clear_power_semiconductor_topology_fault!(bridge.step_down, :controlled, time_s)
        request_power_semiconductor_topology_gates!(
            bridge.step_down, Bool[true, false], time_s,
        )
    elseif sample == 28
        request_power_semiconductor_topology_gates!(
            bridge.npc, Bool[false, true, true, false, false, false], time_s,
        )
        request_power_semiconductor_topology_gates!(
            bridge.t_type, Bool[false, true, true, false], time_s,
        )
        request_power_semiconductor_topology_gates!(
            bridge.flying, Bool[true, false, true, false], time_s,
        )
    elseif sample == 36
        request_power_semiconductor_topology_gates!(
            bridge.cascaded,
            Bool[false, true, true, false, true, false, false, true],
            time_s,
        )
    end
    return bridge
end

function accepted_snapshot(network, result)
    states = [
        power_semiconductor_bridge_topology_state(runtime, result.voltage_v, TIMESTEP_S)
        for runtime in network.all_bridges
    ]
    all(state -> all(isfinite, state.terminal_voltage_v) &&
        all(isfinite, state.terminal_current_a), states) || error(
        "generic bridge topology produced nonfinite terminal state",
    )
    maximum_kcl_residual_a = maximum(abs(state.terminal_kcl_residual_a) for state in states)
    maximum_kcl_residual_a <= 1.0e-7 || error(
        "generic bridge topology terminal KCL residual exceeded tolerance",
    )
    all(state -> state.stored_energy_j >= -1.0e-12 &&
        state.dissipated_energy_j >= -1.0e-12, states) || error(
        "generic bridge topology violated passive storage or dissipation",
    )
    flying_state = states[10]
    return (
        conducting_positions=sum(count(identity, state.conducting_state) for state in states),
        requested_positions=sum(count(identity, state.requested_gate_state) for state in states),
        transition_count=sum(state.transition_count for state in states),
        maximum_kcl_residual_a,
        stored_energy_j=sum(state.stored_energy_j for state in states),
        total_loss_w=sum(state.semiconductor_loss_w + state.passive_dissipated_power_w for state in states),
        diode_dc_voltage_v=result.voltage_v[3],
        full_bridge_dc_voltage_v=result.voltage_v[9],
        flying_capacitor_voltage_v=only(flying_state.passive_voltage_v),
        blocked_topologies=count(state -> state.blocked, states),
        signatures=getfield.(states, :deterministic_signature),
    )
end

function execute_samples!(network, samples)
    snapshots = NamedTuple[]
    for sample in samples
        time_s = sample * TIMESTEP_S
        apply_scheduled_operation!(network.bridge, sample, time_s)
        result = advance_nonlinear_step!(network.system, time_s, TIMESTEP_S)
        result.accepted || error(
            "generic bridge nonlinear solve failed at sample $sample: $(result.failure)",
        )
        push!(snapshots, accepted_snapshot(network, result))
    end
    return snapshots
end

function exact_snapshot_equal(left, right)
    return left.conducting_positions == right.conducting_positions &&
        left.requested_positions == right.requested_positions &&
        left.transition_count == right.transition_count &&
        left.maximum_kcl_residual_a == right.maximum_kcl_residual_a &&
        left.stored_energy_j == right.stored_energy_j &&
        left.total_loss_w == right.total_loss_w &&
        left.diode_dc_voltage_v == right.diode_dc_voltage_v &&
        left.full_bridge_dc_voltage_v == right.full_bridge_dc_voltage_v &&
        left.flying_capacitor_voltage_v == right.flying_capacitor_voltage_v &&
        left.blocked_topologies == right.blocked_topologies &&
        left.signatures == right.signatures
end

function run_public_bridge_case()
    AIMORA.require_solver()
    network = public_bridge_network()
    request_initial_states!(network.bridge)
    prefix = execute_samples!(network, 1:CHECKPOINT_SAMPLE)
    checkpoint = nonlinear_nodal_checkpoint(network.system)
    suffix = execute_samples!(network, (CHECKPOINT_SAMPLE + 1):SAMPLE_COUNT)
    restore_nonlinear_nodal_checkpoint!(network.system, checkpoint)
    replay = execute_samples!(network, (CHECKPOINT_SAMPLE + 1):SAMPLE_COUNT)
    length(suffix) == length(replay) && all(
        exact_snapshot_equal(left, right) for (left, right) in zip(suffix, replay)
    ) || error("generic bridge split-checkpoint replay changed accepted state")
    return vcat(prefix, suffix)
end

function main(args=ARGS)
    snapshots = run_public_bridge_case()
    time_s = collect(1:SAMPLE_COUNT) .* TIMESTEP_S
    output_dir = artifact_directory(args, joinpath(@__DIR__, "outputs"))
    csv_path = write_series_csv(
        joinpath(output_dir, "generic_bridge_topology_library.csv"),
        "time_s",
        time_s,
        [
            "conducting_positions" => getfield.(snapshots, :conducting_positions),
            "requested_positions" => getfield.(snapshots, :requested_positions),
            "transition_count" => getfield.(snapshots, :transition_count),
            "maximum_kcl_residual_a" => getfield.(snapshots, :maximum_kcl_residual_a),
            "stored_energy_j" => getfield.(snapshots, :stored_energy_j),
            "total_loss_w" => getfield.(snapshots, :total_loss_w),
            "diode_dc_voltage_v" => getfield.(snapshots, :diode_dc_voltage_v),
            "full_bridge_dc_voltage_v" => getfield.(snapshots, :full_bridge_dc_voltage_v),
            "flying_capacitor_voltage_v" => getfield.(snapshots, :flying_capacitor_voltage_v),
            "blocked_topologies" => getfield.(snapshots, :blocked_topologies),
        ],
    )
    state_svg_path = write_waveform_svg(
        joinpath(output_dir, "generic_bridge_topology_states.svg"),
        time_s,
        [
            "conducting_positions" => getfield.(snapshots, :conducting_positions),
            "requested_positions" => getfield.(snapshots, :requested_positions),
            "transitions" => getfield.(snapshots, :transition_count),
        ];
        title="Generic Bridge Topology State Evolution",
        y_label="position or transition count",
    )
    physical_svg_path = write_waveform_svg(
        joinpath(output_dir, "generic_bridge_topology_physics.svg"),
        time_s,
        [
            "diode_dc_voltage_v" => getfield.(snapshots, :diode_dc_voltage_v),
            "full_bridge_dc_voltage_v" => getfield.(snapshots, :full_bridge_dc_voltage_v),
            "flying_capacitor_voltage_v" => getfield.(snapshots, :flying_capacitor_voltage_v),
        ];
        title="Generic Bridge Terminal and Passive Voltages",
        y_label="voltage (V)",
    )
    final = last(snapshots)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Generic Bridge Topology Library",
        (
            fidelity="SwitchingDetailed generic topology composition",
            topology_count=11,
            family_count=10,
            valve_position_count=52,
            timestep_s=TIMESTEP_S,
            sample_count=SAMPLE_COUNT,
            checkpoint_sample=CHECKPOINT_SAMPLE,
            exact_split_replay=true,
            extended_fidelity_positions=1,
            final_conducting_positions=final.conducting_positions,
            final_requested_positions=final.requested_positions,
            final_transition_count=final.transition_count,
            maximum_kcl_residual_a=maximum(getfield.(snapshots, :maximum_kcl_residual_a)),
            maximum_stored_energy_j=maximum(getfield.(snapshots, :stored_energy_j)),
            minimum_stored_energy_j=minimum(getfield.(snapshots, :stored_energy_j)),
            final_signature_count=length(unique(final.signatures)),
            manufacturer_identity="none",
            private_solver_required=true,
            unsupported="modulation and controls, complete converter systems, arbitrary topology synthesis, vendor prediction, destructive failure, ATP/PSCAD equivalence, protected-standard conformance, HIL, and certification",
        ),
    )
    println(csv_path)
    println(state_svg_path)
    println(physical_svg_path)
    println(summary_path)
    return nothing
end

main()
