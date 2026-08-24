#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using .ExampleSupport

const DASSL_EXAMPLE_SOLVER_PATH = let configured = strip(get(ENV, "AIMORA_SOLVER_PATH", ""))
    isempty(configured) && error(
        "set AIMORA_SOLVER_PATH to the private AIMORASolvers.jl checkout before executing this case",
    )
    path = abspath(configured)
    isfile(joinpath(path, "src", "AIMORASolvers.jl")) || error(
        "AIMORA_SOLVER_PATH does not identify an AIMORASolvers.jl checkout",
    )
    path
end

pushfirst!(LOAD_PATH, DASSL_EXAMPLE_SOLVER_PATH)
using AIMORASolvers
AIMORA.activate_solver!(AIMORASolvers.production_backend())

const PASSIVE_OUTPUT_TIMES_S = collect(range(0.0, 1.0e-3; length=41))
const SWITCHING_OUTPUT_TIMES_S = [0.0, 2.0e-4, 4.0e-4, 5.5e-4, 7.0e-4, 1.0e-3]
const MACHINE_OUTPUT_TIMES_S = [0.0, 2.0e-5, 5.0e-5, 7.0e-5, 1.0e-4]

function require_condition(condition::Bool, message::AbstractString)
    condition || error(message)
    return nothing
end

function variable_step_settings(; maximum_step_s=2.0e-4, relative_tolerance=1.0e-8)
    return AIMORA.DASSLClassEMTSettings(
        initial_step_s=2.0e-6,
        minimum_step_s=1.0e-10,
        maximum_step_s=maximum_step_s,
        maximum_order=5,
        relative_tolerance=relative_tolerance,
    )
end

function passive_network_request()
    branches = AIMORA.Branches
    source_resistance_ohm = 0.8
    source_voltage_v = 120.0
    load_resistance_ohm = 24.0
    inductance_h = 15.0e-3
    capacitance_f = 100.0e-6
    checkpoint_task = AIMORA.DASSLClassEMTValidationTask(
        :public_checkpoint_boundary,
        5.0e-4,
        10,
        AIMORA.dassl_class_checkpoint_boundary!,
    )
    source = branches.TheveninSource(
        1,
        inv(source_resistance_ohm),
        AIMORA.Sources.SinusoidalSourceSignal(0.0, 0.0, 0.0, source_voltage_v),
    )
    series_branch = branches.SeriesRLCBranch(
        1,
        0,
        load_resistance_ohm,
        inductance_h,
        capacitance_f,
    )
    request = AIMORA.DASSLClassEMTNetworkRequest(
        "public_passive_series_rlc",
        variable_step_settings(),
        1,
        0.0,
        1.0e-3,
        ["source", "series_branch"],
        (source, series_branch);
        initial_node_voltage_v=[source_voltage_v],
        voltage_absolute_tolerance_v=1.0e-8,
        current_absolute_tolerance_a=1.0e-9,
        voltage_residual_scale_v=1.0e-8,
        current_residual_scale_a=1.0e-9,
        requested_output_times_s=PASSIVE_OUTPUT_TIMES_S,
        exact_tasks=(checkpoint_task,),
    )
    return request, (;
        source_resistance_ohm,
        source_voltage_v,
        load_resistance_ohm,
        inductance_h,
        capacitance_f,
    )
end

function execute_passive_network()
    request, parameters = passive_network_request()
    readiness = AIMORA.dassl_class_emt_readiness(request)
    require_condition(readiness.compatible, "the passive public owner set was refused")
    uninterrupted = AIMORA.execute_dassl_class_emt!(
        AIMORA.prepare_dassl_class_emt(request),
    )

    split_request, _ = passive_network_request()
    split_prepared = AIMORA.prepare_dassl_class_emt(split_request)
    prefix = AIMORA.execute_dassl_class_emt!(
        split_prepared;
        stop_after_time_s=5.0e-4,
    )
    snapshot = AIMORA.snapshot_backend_state(split_prepared)
    restored_request, _ = passive_network_request()
    restored = AIMORA.prepare_dassl_class_emt(restored_request)
    AIMORA.restore_backend_state!(restored, snapshot)
    suffix = AIMORA.execute_dassl_class_emt!(restored)
    restart_exact =
        vcat(prefix.time_s, suffix.time_s) == uninterrupted.time_s &&
        hcat(prefix.state, suffix.state) == uninterrupted.state &&
        hcat(prefix.derivative, suffix.derivative) == uninterrupted.derivative &&
        vcat(prefix.transition_side, suffix.transition_side) == uninterrupted.transition_side &&
        suffix.diagnostics == uninterrupted.diagnostics &&
        suffix.numerical_snapshot_signature == uninterrupted.numerical_snapshot_signature
    require_condition(restart_exact, "passive split/restart changed the accepted result")

    node_voltage_v = vec(uninterrupted.state[1, :])
    current_a = vec(uninterrupted.state[2, :])
    capacitor_voltage_v = vec(uninterrupted.state[3, :])
    current_rate_a_per_s = vec(uninterrupted.derivative[2, :])
    capacitor_rate_v_per_s = vec(uninterrupted.derivative[3, :])
    maximum_kvl_residual_v = maximum(abs,
        parameters.inductance_h .* current_rate_a_per_s .-
        (node_voltage_v .- parameters.load_resistance_ohm .* current_a .-
         capacitor_voltage_v),
    )
    maximum_charge_residual_a = maximum(abs,
        parameters.capacitance_f .* capacitor_rate_v_per_s .- current_a,
    )
    stored_energy_j =
        0.5 .* parameters.inductance_h .* current_a .^ 2 .+
        0.5 .* parameters.capacitance_f .* capacitor_voltage_v .^ 2
    require_condition(maximum_kvl_residual_v <= 2.0e-4,
        "passive KVL residual $(maximum_kvl_residual_v) V exceeded 2e-4 V")
    require_condition(maximum_charge_residual_a <= 1.0e-5,
        "passive charge residual $(maximum_charge_residual_a) A exceeded 1e-5 A")
    require_condition(all(>=(0.0), stored_energy_j), "passive stored energy became negative")
    return (; uninterrupted, readiness, restart_exact, snapshot,
        node_voltage_v, current_a, capacitor_voltage_v, stored_energy_j,
        maximum_kvl_residual_v, maximum_charge_residual_a)
end

function switching_network_request()
    branches = AIMORA.Branches
    nonlinear = AIMORA.NonlinearNetwork
    switches = AIMORA.Switches
    source = branches.TheveninSource(
        1,
        1.0,
        AIMORA.Sources.SinusoidalSourceSignal(0.0, 0.0, 0.0, 10.0),
    )
    load = branches.ConductanceBranch(1, 0, 1.0)
    capacitor = branches.CapacitorBranch(1, 0, 1.0e-3, 0.0, 5.0, 0.0)
    cubic = nonlinear.CubicCurrentBranch(
        1,
        0;
        linear_conductance_s=0.1,
        cubic_coefficient_a_per_v3=1.0e-3,
    )
    time_switch = switches.TimeSwitch(
        1,
        0;
        close_time_s=4.0e-4,
        open_time_s=7.0e-4,
        initially_closed=false,
        on_conductance=1.0,
        off_conductance=0.0,
    )
    return AIMORA.DASSLClassEMTNetworkRequest(
        "public_nonlinear_exact_switching",
        variable_step_settings(maximum_step_s=5.0e-5, relative_tolerance=1.0e-7),
        1,
        0.0,
        1.0e-3,
        ["source", "load", "capacitor", "cubic_law", "time_switch"],
        (source, load, capacitor, cubic, time_switch);
        initial_node_voltage_v=[5.0],
        voltage_absolute_tolerance_v=1.0e-8,
        current_absolute_tolerance_a=1.0e-9,
        voltage_residual_scale_v=1.0e-8,
        current_residual_scale_a=1.0e-9,
        requested_output_times_s=SWITCHING_OUTPUT_TIMES_S,
    )
end

function execute_switching_network()
    request = switching_network_request()
    readiness = AIMORA.dassl_class_emt_readiness(request)
    require_condition(readiness.compatible, "the nonlinear switching owner set was refused")
    result = AIMORA.execute_dassl_class_emt!(AIMORA.prepare_dassl_class_emt(request))
    require_condition(result.diagnostics.consistency_restarts == 2,
        "the two exact switch boundaries did not restart DAE consistency")
    require_condition(count(==(:left), result.transition_side) == 2,
        "the switch result omitted a left transition state")
    require_condition(count(==(:right), result.transition_side) == 2,
        "the switch result omitted a right transition state")
    require_condition(any(owner -> owner.code == :admitted_memoryless_nonlinear_law,
        readiness.owners), "the cubic current owner was not admitted")
    require_condition(any(owner -> owner.code == :admitted_exact_time_switch,
        readiness.owners), "the exact time-switch owner was not admitted")
    return (; result, readiness)
end

function controlled_machine_request()
    branches = AIMORA.Branches
    modern = AIMORA.ModernMachines
    synchronous_speed_rad_s = 2.0 * pi * 60.0 / 2.0
    controls = modern.MachineControlParameters(
        enabled=true,
        task_period_s=5.0e-5,
        task_phase_s=2.0e-5,
        voltage_reference_v=100.0,
        excitation_gain=0.01,
        excitation_time_constant_s=0.02,
        field_voltage_min_v=0.0,
        field_voltage_max_v=20.0,
        speed_reference_rad_s=synchronous_speed_rad_s,
        governor_droop_rad_s_per_nm=0.1,
        governor_time_constant_s=0.04,
        torque_min_nm=-50.0,
        torque_max_nm=50.0,
        stabilizer_gain=0.01,
        stabilizer_washout_s=0.1,
        stabilizer_lead_s=0.02,
        stabilizer_lag_s=0.05,
    )
    specification = modern.ModernMachineSpecification(
        :public_variable_step_wound_field_machine,
        modern.WoundFieldSynchronousMachine;
        operating_mode=modern.MachineGeneratorMode,
        pole_pairs=2,
        electrical=modern.MachineElectricalParameters(
            stator_resistance_ohm=0.18,
            zero_sequence_inductance_h=0.012,
            stator_d_leakage_inductance_h=0.006,
            stator_q_leakage_inductance_h=0.007,
            d_axis_magnetizing_inductance_h=0.085,
            q_axis_magnetizing_inductance_h=0.072,
            field_resistance_ohm=1.2,
            field_leakage_inductance_h=0.018,
            d_damper_resistance_ohm=0.45,
            d_damper_leakage_inductance_h=0.011,
            q_damper_resistance_ohm=0.52,
            q_damper_leakage_inductance_h=0.013,
            iron_loss_conductance_s=1.0e-5,
        ),
        shaft_masses=[modern.MachineShaftMass(
            :electromagnetic_mass;
            inertia_kg_m2=1.75,
            damping_nm_s_per_rad=0.002,
            initial_speed_rad_s=synchronous_speed_rad_s,
        )],
        electromagnetic_mass=:electromagnetic_mass,
        controls,
        settings=modern.MachineRuntimeSettings(
            timestep_s=1.0e-5,
            nonlinear_tolerance=1.0e-12,
            maximum_nonlinear_iterations=16,
            energy_tolerance_j=1.0e-6,
        ),
        initialization_mode=modern.SpecifiedMachineInitialization,
        initial_phase_voltage_v=(100.0, -50.0, -50.0),
        initial_field_voltage_v=5.0,
        initial_mechanical_torque_nm=0.0,
        uncertainty="deterministic synthetic public variable-step machine case",
        validity_domain="short balanced source-fed wound-field machine and sampled-control execution",
    )
    preparation = modern.prepare_modern_machine(specification)
    event = modern.ModernMachineEvent(
        :field_voltage_source_step,
        5.0e-5,
        modern.MachineFieldVoltageEvent;
        value=6.0,
        priority=0,
    )
    runtime = modern.modern_machine_runtime(
        preparation,
        (1, 2, 3, 4);
        events=(event,),
    )
    phase_voltage_v = (100.0, -50.0, -50.0)
    sources = Tuple(branches.TheveninSource(
        node,
        1.0e3,
        AIMORA.Sources.SinusoidalSourceSignal(
            0.0,
            0.0,
            0.0,
            phase_voltage_v[node],
        ),
    ) for node in 1:3)
    neutral = branches.ConductanceBranch(4, 0, 1.0e3)
    request = AIMORA.DASSLClassEMTNetworkRequest(
        "public_wound_field_machine_control",
        AIMORA.DASSLClassEMTSettings(
            initial_step_s=1.0e-6,
            minimum_step_s=1.0e-10,
            maximum_step_s=1.0e-5,
            maximum_order=5,
            relative_tolerance=1.0e-6,
        ),
        4,
        0.0,
        1.0e-4,
        ["phase_a_source", "phase_b_source", "phase_c_source", "neutral", "machine"],
        (sources..., neutral, runtime);
        initial_node_voltage_v=[100.0, -50.0, -50.0, 0.0],
        voltage_absolute_tolerance_v=1.0e-7,
        current_absolute_tolerance_a=1.0e-8,
        flux_absolute_tolerance_wb=1.0e-9,
        angle_absolute_tolerance_rad=1.0e-9,
        speed_absolute_tolerance_rad_s=1.0e-7,
        voltage_residual_scale_v=1.0e-7,
        current_residual_scale_a=1.0e-8,
        flux_residual_scale_v=1.0e-7,
        angle_residual_scale_rad_s=1.0e-7,
        speed_residual_scale_rad_s2=1.0e-6,
        requested_output_times_s=MACHINE_OUTPUT_TIMES_S,
    )
    return request, runtime
end

function execute_controlled_machine()
    request, runtime = controlled_machine_request()
    readiness = AIMORA.dassl_class_emt_readiness(request)
    require_condition(readiness.compatible, "the wound-field machine/control owner was refused")
    require_condition(any(owner -> owner.code == :admitted_wound_field_machine,
        readiness.owners), "the readiness matrix omitted the admitted machine owner")
    result = AIMORA.execute_dassl_class_emt!(AIMORA.prepare_dassl_class_emt(request))
    require_condition(runtime.accepted_state.event_count == 1,
        "the machine source event did not execute exactly once")
    require_condition(runtime.control_state.sample_count == 2,
        "the sampled machine control did not execute twice")
    require_condition(result.diagnostics.consistency_restarts == 3,
        "the machine event/control boundaries did not restart consistency")
    speed_identity = :machine_shaft_electromagnetic_mass_speed_rad_s
    speed_index = findfirst(==(speed_identity), result.layout.identities)
    speed_index === nothing && error("the machine result omitted shaft speed")
    return (; result, readiness, runtime, speed_index)
end

function unsupported_owner_readiness()
    branches = AIMORA.Branches
    owner = branches.IdealTransformerVoltageConstraint(1, 2, 3, 4, 5, 1.0)
    request = AIMORA.DASSLClassEMTNetworkRequest(
        "public_unsupported_transformer_constraint",
        variable_step_settings(),
        5,
        0.0,
        1.0e-3,
        ["ideal_transformer_constraint"],
        (owner,);
        initial_node_voltage_v=zeros(5),
        voltage_absolute_tolerance_v=1.0e-8,
        current_absolute_tolerance_a=1.0e-9,
        voltage_residual_scale_v=1.0e-8,
        current_residual_scale_a=1.0e-9,
    )
    readiness = AIMORA.dassl_class_emt_readiness(request)
    require_condition(!readiness.compatible,
        "an unsupported transformer constraint was silently admitted")
    require_condition(only(readiness.owners).code == :owner_type_not_admitted,
        "the unsupported transformer returned the wrong refusal code")
    prepared = AIMORA.prepare_dassl_class_emt(request)
    require_condition(prepared isa AIMORA.DASSLClassEMTReadiness && !prepared.compatible,
        "unsupported preparation did not return typed readiness refusal")
    return readiness
end

function write_result_contract(path, named_results, refusal)
    open(path, "w") do io
        println(io, "case,compatible,state_count,differential_state_count,algebraic_state_count,accepted_steps,rejected_steps,consistency_restarts,localized_roots,numerical_snapshot_signature,deterministic_signature")
        for (name, result) in named_results
            diagnostics = result.diagnostics
            println(io, join((
                name,
                result.readiness.compatible,
                result.readiness.state_count,
                result.readiness.differential_state_count,
                result.readiness.algebraic_state_count,
                diagnostics.accepted_steps,
                diagnostics.rejected_steps,
                diagnostics.consistency_restarts,
                diagnostics.localized_roots,
                result.numerical_snapshot_signature,
                result.deterministic_signature,
            ), ','))
        end
        owner = only(refusal.owners)
        println(io, join((
            "unsupported_transformer_constraint",
            refusal.compatible,
            refusal.state_count,
            refusal.differential_state_count,
            refusal.algebraic_state_count,
            0,
            0,
            0,
            0,
            refusal.signature,
            String(owner.code),
        ), ','))
    end
    return abspath(path)
end

function main()
    output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    require_condition(AIMORA.EMTIntegrationSelection().mode == AIMORA.FixedStepEMT,
        "the default EMT integration mode is no longer fixed-step")
    selected = AIMORA.EMTIntegrationSelection(variable_step_settings())
    require_condition(selected.mode == AIMORA.DASSLClassVariableStep,
        "the explicit DASSL-class selection was not retained")

    passive = execute_passive_network()
    switching = execute_switching_network()
    machine = execute_controlled_machine()
    refusal = unsupported_owner_readiness()

    passive_csv = write_series_csv(
        joinpath(output_directory, "passive_dense_output.csv"),
        "time_s",
        passive.uninterrupted.time_s,
        Pair{String,Vector{Float64}}[
            "node_voltage_v" => passive.node_voltage_v,
            "branch_current_a" => passive.current_a,
            "capacitor_voltage_v" => passive.capacitor_voltage_v,
            "stored_energy_j" => passive.stored_energy_j,
        ],
    )
    passive_svg = write_waveform_svg(
        joinpath(output_directory, "passive_dense_output.svg"),
        passive.uninterrupted.time_s,
        Pair{String,Vector{Float64}}[
            "node voltage (V)" => passive.node_voltage_v,
            "capacitor voltage (V)" => passive.capacitor_voltage_v,
            "branch current (A)" => passive.current_a,
        ];
        title="DASSL-Class Passive RLC Dense Output",
        y_label="declared SI value",
    )
    switching_csv = write_series_csv(
        joinpath(output_directory, "nonlinear_switching_output.csv"),
        "time_s",
        switching.result.time_s,
        Pair{String,Vector{Float64}}[
            "node_voltage_v" => vec(switching.result.state[1, :]),
            "capacitor_voltage_v" => vec(switching.result.state[2, :]),
            "capacitor_current_a" => vec(switching.result.state[3, :]),
        ],
    )
    switching_svg = write_waveform_svg(
        joinpath(output_directory, "nonlinear_switching_output.svg"),
        switching.result.time_s,
        Pair{String,Vector{Float64}}[
            "node voltage (V)" => vec(switching.result.state[1, :]),
            "capacitor current (A)" => vec(switching.result.state[3, :]),
        ];
        title="DASSL-Class Nonlinear Exact Switching",
        y_label="declared SI value",
    )
    machine_csv = write_series_csv(
        joinpath(output_directory, "machine_control_output.csv"),
        "time_s",
        machine.result.time_s,
        Pair{String,Vector{Float64}}[
            "phase_a_voltage_v" => vec(machine.result.state[1, :]),
            "phase_b_voltage_v" => vec(machine.result.state[2, :]),
            "phase_c_voltage_v" => vec(machine.result.state[3, :]),
            "shaft_speed_rad_s" => vec(machine.result.state[machine.speed_index, :]),
        ],
    )
    machine_svg = write_waveform_svg(
        joinpath(output_directory, "machine_control_output.svg"),
        machine.result.time_s,
        Pair{String,Vector{Float64}}[
            "phase a voltage (V)" => vec(machine.result.state[1, :]),
            "shaft speed (rad/s)" => vec(machine.result.state[machine.speed_index, :]),
        ];
        title="DASSL-Class Wound-Field Machine and Sampled Control",
        y_label="declared SI value",
    )
    result_contract = write_result_contract(
        joinpath(output_directory, "result_contract.csv"),
        (
            "passive_series_rlc" => passive.uninterrupted,
            "nonlinear_exact_switching" => switching.result,
            "wound_field_machine_control" => machine.result,
        ),
        refusal,
    )
    summary = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Optional DASSL-Class Variable-Step EMT Public Case",
        (
            default_mode=AIMORA.EMTIntegrationSelection().mode,
            selected_mode=selected.mode,
            solver_path_configured=true,
            passive_owner_count=length(passive.readiness.owners),
            passive_maximum_kvl_residual_v=passive.maximum_kvl_residual_v,
            passive_maximum_charge_residual_a=passive.maximum_charge_residual_a,
            passive_split_restart_exact=passive.restart_exact,
            passive_snapshot_signature=passive.snapshot.signature_sha256,
            nonlinear_owner_count=length(switching.readiness.owners),
            nonlinear_consistency_restarts=switching.result.diagnostics.consistency_restarts,
            machine_state_count=machine.readiness.state_count,
            machine_event_count=machine.runtime.accepted_state.event_count,
            machine_control_sample_count=machine.runtime.control_state.sample_count,
            refusal_code=only(refusal.owners).code,
            fixed_step_default_preserved=true,
            unsupported="switch-detailed PWM/semiconductors, frequency-dependent histories without reconstruction, unsupported transformer/hysteresis owners, partitioned/subcycled execution, stochastic/native-extension delays, real-time/HIL, arbitrary high-index DAEs, universal speedup, ATP/PSCAD compatibility, standard conformance, certification, and unexecuted operating systems",
        ),
    )

    println("Passive CSV: ", passive_csv)
    println("Passive SVG: ", passive_svg)
    println("Nonlinear switching CSV: ", switching_csv)
    println("Nonlinear switching SVG: ", switching_svg)
    println("Machine/control CSV: ", machine_csv)
    println("Machine/control SVG: ", machine_svg)
    println("Result contract: ", result_contract)
    println("Summary: ", summary)
end

main()
