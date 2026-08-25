#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using .ExampleSupport

const CONVERTERS = AIMORA.ConverterSystems
const CORE = AIMORA.StudyCore
const FIDELITIES = (
    CORE.AverageValue,
    CORE.SwitchingStateEquivalent,
    CORE.SwitchingDetailed,
)
const FIXED_STEP_S = 0.25e-6
const STOP_TIME_S = 300.0e-6
const CARRIER_FREQUENCY_HZ = 10_000.0
const DUTY = 0.6
const CHECKPOINT_STEP = 600

fidelity_name(fidelity) = string(fidelity)

function public_capability_rows()
    rows = NamedTuple[]
    for family in instances(CONVERTERS.ConverterSystemFamily)
        executable = CONVERTERS.converter_executable_fidelities(family)
        modulations = join(string.(CONVERTERS.converter_supported_modulations(family)), ';')
        for fidelity in FIDELITIES
            admitted = fidelity in executable
            push!(rows, (
                category=String(CONVERTERS.converter_family_category(family)),
                family=string(family),
                application=string(CONVERTERS.StandaloneConversion),
                fidelity=fidelity_name(fidelity),
                admitted,
                disposition=admitted ? "executable" : "typed_unsupported_fidelity",
                modulations,
            ))
        end
    end
    for application in instances(CONVERTERS.ConverterApplication)
        application === CONVERTERS.StandaloneConversion && continue
        family = CONVERTERS.ThreePhaseTwoLevelBridge
        executable = CONVERTERS.converter_executable_fidelities(family, application)
        modulations = join(string.(CONVERTERS.converter_supported_modulations(family)), ';')
        for fidelity in FIDELITIES
            admitted = fidelity in executable
            push!(rows, (
                category="application",
                family=string(family),
                application=string(application),
                fidelity=fidelity_name(fidelity),
                admitted,
                disposition=admitted ? "executable" : "typed_unsupported_fidelity",
                modulations,
            ))
        end
    end
    standalone_admitted = count(row ->
        row.application == string(CONVERTERS.StandaloneConversion) && row.admitted,
        rows,
    )
    application_admitted = count(row ->
        row.application != string(CONVERTERS.StandaloneConversion) && row.admitted,
        rows,
    )
    length(rows) == 81 || error("public converter matrix must contain 81 candidates")
    standalone_admitted == 52 || error(
        "public converter matrix must contain 52 executable standalone intersections",
    )
    application_admitted == 5 || error(
        "public converter matrix must contain five executable application compositions",
    )
    return rows
end

function write_capability_matrix(path, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "category,family,application,fidelity,admitted,disposition,modulations")
        for row in rows
            println(io, join((
                row.category,
                row.family,
                row.application,
                row.fidelity,
                row.admitted,
                row.disposition,
                row.modulations,
            ), ','))
        end
    end
    return abspath(path)
end

function public_semiconductor_provenance()
    return CORE.ParameterProvenance(
        "AIMORA public generic extended-converter buck parameters",
        "SI",
        "direct AIMORA-authored synthetic values",
        "unknown nonstatistical component uncertainty",
        "120 V fixed-step switching-detailed public buck case",
        CORE.PhysicalModelParameter,
    )
end

function public_switching_detailed_buck_study()
    topology = AIMORA.BridgeTopologies.step_down_chopper_topology(1, 2, 0)
    provenance = public_semiconductor_provenance()
    semiconductor = CONVERTERS.DetailedChopperSemiconductorParameters(;
        controlled_on_conductance_s=240.0,
        controlled_off_conductance_s=2.0e-6,
        controlled_forward_voltage_v=1.05,
        freewheel_on_conductance_s=220.0,
        freewheel_off_conductance_s=2.0e-6,
        freewheel_forward_voltage_v=0.85,
        controlled_junction_capacitance_f=1.4e-9,
        freewheel_junction_capacitance_f=2.8e-9,
        junction_potential_v=160.0,
        junction_grading_exponent=0.45,
        recovered_charge_lifetime_s=4.0e-6,
        turn_off_tail_time_s=3.5e-6,
        turn_off_tail_cutoff_current_a=2.0e-3,
        snubber_resistance_ohm=150.0e3,
        snubber_capacitance_f=150.0e-12,
        switching_energy_current_domain_maximum_a=5_000.0,
        switching_energy_blocking_voltage_domain_maximum_v=1_000.0,
        turn_on_energy_at_domain_maximum_j=0.6e-3,
        turn_off_energy_at_domain_maximum_j=0.9e-3,
        reverse_recovery_energy_at_domain_maximum_j=0.35e-3,
        thermal_capacitance_j_per_k=(0.4, 4.0),
        thermal_resistance_k_per_w=(0.18, 0.72),
        ambient_temperature_k=298.15,
        junction_voltage_limit_v=1_000.0,
        provenance=provenance,
    )
    commands = (
        CONVERTERS.ConverterSystemEventCommand(
            :public_controlled_path_block,
            CONVERTERS.ConverterBlockEvent,
            120.0e-6;
            target_valve_indices=(1,),
        ),
        CONVERTERS.ConverterSystemEventCommand(
            :public_controlled_path_restart,
            CONVERTERS.ConverterRestartEvent,
            180.0e-6;
            target_valve_indices=(1,),
            reference_id=:public_controlled_path_block,
        ),
    )
    specification = CONVERTERS.ConverterSystemSpecification(
        :public_switching_detailed_buck_converter,
        CONVERTERS.ConverterSystemSelection(
            CONVERTERS.BuckChopper,
            CORE.SwitchingDetailed;
            phase_count=1,
            thermal_stage_count=2,
        ),
        (
            CONVERTERS.ConverterPortDefinition(
                :input_dc,
                CONVERTERS.DirectCurrentPort,
                (1, 0);
                voltage_orientation="positive from input positive to common negative",
            ),
            CONVERTERS.ConverterPortDefinition(
                :output_dc,
                CONVERTERS.DirectCurrentPort,
                (3, 0);
                voltage_orientation="positive from output positive to common negative",
            ),
        ),
        (AIMORA.BridgeTopologies.bridge_topology_signature(topology),),
        CONVERTERS.detailed_chopper_semiconductor_signatures(semiconductor),
        ("physical_series_inductor_and_output_capacitor",),
        CONVERTERS.ConverterRatedBases(160.0, 25.0, 4_000.0, CARRIER_FREQUENCY_HZ),
        CONVERTERS.ConverterTimingParameters(
            fixed_step_s=FIXED_STEP_S,
            control_period_s=100.0e-6,
            carrier_frequency_hz=CARRIER_FREQUENCY_HZ,
        ),
        CONVERTERS.ConverterModulationParameters(
            kind=CONVERTERS.CarrierSinusoidalPulseWidthModulation,
            duty=DUTY,
        ),
        (provenance,),
        CORE.ModelValidityDomain(
            :public_switching_detailed_buck_converter;
            description="AIMORA-authored 120 V fixed-step switching-detailed buck workflow",
        );
        event_commands=commands,
    )
    initial_state = CONVERTERS.average_buck_operating_point(120.0, DUTY, 0.08, 0.12, 8.0)
    return CONVERTERS.SwitchingBuckConverterStudy(
        specification;
        topology,
        input_voltage_v=120.0,
        source_resistance_ohm=0.08,
        inductor_resistance_ohm=0.12,
        inductance_h=1.5e-3,
        capacitance_f=150.0e-6,
        load_resistance_ohm=8.0,
        initial_state,
        detailed_semiconductor=semiconductor,
        stop_time_s=STOP_TIME_S,
    )
end

function trace_equal(left, right)
    fields = (
        :time_s,
        :input_voltage_v,
        :input_current_a,
        :switch_node_voltage_v,
        :output_voltage_v,
        :inductor_current_a,
        :load_current_a,
        :requested_gate_state,
        :applied_gate_state,
        :controlled_valve_conducting_state,
        :freewheel_diode_conducting_state,
        :stored_energy_j,
        :semiconductor_loss_w,
        :kcl_residual_a,
        :energy_residual_w,
        :controlled_junction_temperature_k,
        :freewheel_junction_temperature_k,
        :freewheel_recovered_charge_c,
        :controlled_turn_off_tail_current_a,
        :controlled_junction_stored_energy_j,
        :freewheel_junction_stored_energy_j,
    )
    return all(field -> getfield(left, field) == getfield(right, field), fields) &&
        left.result.state.deterministic_signature_sha256 ==
            right.result.state.deterministic_signature_sha256
end

function execute_public_workflow()
    AIMORA.require_solver()
    study = public_switching_detailed_buck_study()
    readiness = CONVERTERS.converter_system_readiness(study.specification)
    CONVERTERS.converter_system_is_ready(readiness) || error(
        "public switching-detailed buck was refused: $(readiness.message)",
    )
    uninterrupted_runtime = AIMORA.prepare_converter_system(study)
    uninterrupted = AIMORA.execute_converter_system!(uninterrupted_runtime)
    uninterrupted.result.accepted || error("public converter result was not accepted")
    uninterrupted.result.status === :ok || error("public converter result status is not ok")

    split_runtime = AIMORA.prepare_converter_system(study)
    AIMORA.advance_converter_system!(split_runtime, CHECKPOINT_STEP)
    snapshot = AIMORA.snapshot_backend_state(split_runtime)
    restored_runtime = AIMORA.prepare_converter_system(study)
    AIMORA.restore_backend_state!(restored_runtime, snapshot)
    split = AIMORA.execute_converter_system!(restored_runtime)
    trace_equal(uninterrupted, split) || error(
        "portable converter snapshot changed exact continuation",
    )
    final_uninterrupted_snapshot = AIMORA.snapshot_backend_state(uninterrupted_runtime)
    final_split_snapshot = AIMORA.snapshot_backend_state(restored_runtime)
    final_uninterrupted_snapshot.signature_sha256 == final_split_snapshot.signature_sha256 ||
        error("portable converter final snapshot signature changed")

    maximum(abs, uninterrupted.kcl_residual_a) <= 1.0e-6 || error(
        "public converter KCL residual exceeded 1 microampere",
    )
    uninterrupted.result.relative_energy_residual <= 5.0e-3 || error(
        "public converter relative energy residual exceeded 0.5 percent",
    )
    minimum(uninterrupted.freewheel_recovered_charge_c) >= 0.0 || error(
        "public converter recovered charge became negative",
    )
    minimum(uninterrupted.controlled_turn_off_tail_current_a) >= 0.0 || error(
        "public converter turn-off tail current became negative",
    )
    all(>(0.0), uninterrupted.controlled_junction_temperature_k) || error(
        "public converter controlled-device temperature became nonpositive",
    )
    all(>(0.0), uninterrupted.freewheel_junction_temperature_k) || error(
        "public converter diode temperature became nonpositive",
    )
    event_kinds = getfield.(uninterrupted.result.events, :kind)
    count(==(:converter_block), event_kinds) == 1 || error(
        "public converter block event did not occur exactly once",
    )
    count(==(:converter_restart), event_kinds) == 1 || error(
        "public converter restart event did not occur exactly once",
    )
    return (;
        study,
        trace=uninterrupted,
        checkpoint_signature=snapshot.signature_sha256,
        final_snapshot_signature=final_uninterrupted_snapshot.signature_sha256,
    )
end

function write_result_contract(path, execution)
    result = execution.trace.result
    open(path, "w") do io
        println(io, "schema,accepted,status,family,fidelity,application,accepted_steps,event_count,maximum_kcl_residual_a,relative_charge_residual,relative_energy_residual,specification_signature,deterministic_signature,checkpoint_signature,final_snapshot_signature,exact_split_restart")
        println(io, join((
            result.schema,
            result.accepted,
            result.status,
            result.family,
            result.fidelity,
            result.application,
            result.state.accepted_step_count,
            result.state.event_count,
            result.maximum_kcl_residual_a,
            result.relative_charge_residual,
            result.relative_energy_residual,
            result.specification_signature_sha256,
            result.state.deterministic_signature_sha256,
            execution.checkpoint_signature,
            execution.final_snapshot_signature,
            true,
        ), ','))
    end
    return abspath(path)
end

function main(args=ARGS)
    rows = public_capability_rows()
    execution = execute_public_workflow()
    trace = execution.trace
    output_directory = artifact_directory(args, joinpath(@__DIR__, "outputs"))
    matrix_path = write_capability_matrix(
        joinpath(output_directory, "converter_family_fidelity_matrix.csv"),
        rows,
    )
    waveform_path = write_series_csv(
        joinpath(output_directory, "switching_detailed_buck_waveform.csv"),
        "time_s",
        trace.time_s,
        [
            "input_voltage_v" => trace.input_voltage_v,
            "input_current_a" => trace.input_current_a,
            "switch_node_voltage_v" => trace.switch_node_voltage_v,
            "output_voltage_v" => trace.output_voltage_v,
            "inductor_current_a" => trace.inductor_current_a,
            "load_current_a" => trace.load_current_a,
            "requested_gate_state" => trace.requested_gate_state,
            "applied_gate_state" => trace.applied_gate_state,
            "controlled_valve_conducting_state" => trace.controlled_valve_conducting_state,
            "freewheel_diode_conducting_state" => trace.freewheel_diode_conducting_state,
            "stored_energy_j" => trace.stored_energy_j,
            "semiconductor_loss_w" => trace.semiconductor_loss_w,
            "kcl_residual_a" => trace.kcl_residual_a,
            "energy_residual_w" => trace.energy_residual_w,
            "controlled_junction_temperature_k" => trace.controlled_junction_temperature_k,
            "freewheel_junction_temperature_k" => trace.freewheel_junction_temperature_k,
            "freewheel_recovered_charge_c" => trace.freewheel_recovered_charge_c,
            "controlled_turn_off_tail_current_a" =>
                trace.controlled_turn_off_tail_current_a,
        ],
    )
    electrical_svg = write_waveform_svg(
        joinpath(output_directory, "switching_detailed_buck_electrical.svg"),
        trace.time_s,
        [
            "switch node voltage (V)" => trace.switch_node_voltage_v,
            "output voltage (V)" => trace.output_voltage_v,
            "inductor current (A)" => trace.inductor_current_a,
        ];
        title="Switching-Detailed Buck Electrical Response",
        y_label="declared SI value",
    )
    device_svg = write_waveform_svg(
        joinpath(output_directory, "switching_detailed_buck_device_state.svg"),
        trace.time_s,
        [
            "controlled temperature rise (mK)" =>
                1.0e3 .* (trace.controlled_junction_temperature_k .- 298.15),
            "freewheel temperature rise (mK)" =>
                1.0e3 .* (trace.freewheel_junction_temperature_k .- 298.15),
            "recovered charge (uC)" => 1.0e6 .* trace.freewheel_recovered_charge_c,
            "turn-off tail current (A)" => trace.controlled_turn_off_tail_current_a,
        ];
        title="Switching-Detailed Buck Device State",
        y_label="scaled detailed-device quantity",
    )
    result_contract = write_result_contract(
        joinpath(output_directory, "converter_result_contract.csv"),
        execution,
    )
    standalone_rows = filter(row ->
        row.application == string(CONVERTERS.StandaloneConversion), rows)
    summary_path = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Extended Converter Systems Public Case",
        (
            converter_family_count=length(instances(CONVERTERS.ConverterSystemFamily)),
            standalone_candidate_intersections=length(standalone_rows),
            executable_standalone_intersections=count(getfield.(standalone_rows, :admitted)),
            unsupported_standalone_intersections=count(.!getfield.(standalone_rows, :admitted)),
            application_count=length(instances(CONVERTERS.ConverterApplication)) - 1,
            executable_application_compositions=count(row ->
                row.application != string(CONVERTERS.StandaloneConversion) && row.admitted,
                rows,
            ),
            matrix_row_count=length(rows),
            executed_family=trace.result.family,
            executed_fidelity=trace.result.fidelity,
            fixed_step_s=FIXED_STEP_S,
            accepted_step_count=trace.result.state.accepted_step_count,
            event_count=trace.result.state.event_count,
            exact_split_restart=true,
            maximum_kcl_residual_a=trace.result.maximum_kcl_residual_a,
            relative_energy_residual=trace.result.relative_energy_residual,
            peak_output_voltage_v=maximum(trace.output_voltage_v),
            peak_inductor_current_a=maximum(abs, trace.inductor_current_a),
            maximum_controlled_junction_temperature_k=
                maximum(trace.controlled_junction_temperature_k),
            maximum_freewheel_junction_temperature_k=
                maximum(trace.freewheel_junction_temperature_k),
            deterministic_signature=trace.result.state.deterministic_signature_sha256,
            manufacturer_identity="none",
            private_solver_required=true,
            unsupported="manufacturer prediction, product design, arbitrary synthesis, destructive failure, renewable plants, FACTS, HVDC, MMC, ATP/PSCAD equivalence, protected-standard conformance, field validation, safety, HIL, and certification",
        ),
    )
    println(matrix_path)
    println(waveform_path)
    println(electrical_svg)
    println(device_svg)
    println(result_contract)
    println(summary_path)
    return nothing
end

main()
