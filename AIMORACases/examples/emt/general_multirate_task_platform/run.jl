#!/usr/bin/env julia

using Dates

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.EMTStudy
using AIMORA.EMTTaskPlatform
using AIMORAProject
using .ExampleSupport

const CASE_DECK = joinpath(
    @__DIR__,
    "..",
    "control_network_feedback",
    "control_network_feedback.deck",
)
const HORIZON = emt_logical_time(300 // 1_000_000)
const EVENT_INSTANT = emt_logical_time(75 // 1_000_000)
const TASK_PERIODS_US = (25, 25, 30, 30, 40, 40, 45, 45, 50, 50, 60, 60, 75, 75, 100, 100)
const TASK_PHASES_US = (0, 5, 0, 15, 5, 15, 0, 30, 0, 25, 0, 15, 0, 25, 0, 75)
const TASK_DELAYS_US = (0, 20, 15, 0, 30, 10, 5, 0, 25, 0, 15, 0, 0, 50, 0, 0)

mutable struct PublicTaskState
    family_rank::Int
    predecessor_key::Union{Nothing,Symbol}
    output_key::Symbol
    activation_count::Int
    fail_on_activation::Int
end

struct ReadPublicTask end

function (::ReadPublicTask)(state, owner, _instant, activation_index)
    runtime = something(owner.runtime.context.control_system_runtime)
    input = runtime.state.values[:GENERAL_TASK_INPUT]
    predecessor = state.predecessor_key === nothing ? 0.0 :
        runtime.state.values[state.predecessor_key]
    return (input, predecessor, activation_index)
end

struct ComputePublicTask end

function (::ComputePublicTask)(state, _owner, input, _instant, activation_index)
    activation_index == state.fail_on_activation && error(
        "requested public general-task rollback probe",
    )
    source, predecessor, sample_index = input
    return source + state.family_rank / 10 + predecessor / 100 + sample_index / 1_000
end

struct WritePublicTask end

function (::WritePublicTask)(state, owner, value, _instant, _sample_index)
    runtime = something(owner.runtime.context.control_system_runtime)
    runtime.state.values[state.output_key] = value
    state.activation_count += 1
    if state.output_key === :GENERAL_TASK_OUTPUT_16
        runtime.state.values[:DRIVEN] = 0.1 * value
    end
    return nothing
end

struct PublicTaskEventValue end

(::PublicTaskEventValue)(_owner) = nothing

struct ApplyPublicTaskEvent end

function (::ApplyPublicTaskEvent)(owner, _time_s)
    runtime = something(owner.runtime.context.control_system_runtime)
    runtime.state.values[:GENERAL_TASK_INPUT] = 2.0
    return nothing
end

struct PublicTaskEventCandidate end

(::PublicTaskEventCandidate)(_owner) = Float64(EVENT_INSTANT)

function public_task_time(microseconds::Integer, provenance)
    return PhysicalValue(
        ScalarQuantity(
            parse_exact_decimal("$(microseconds)e-6"),
            UnitId("s"),
            OrientationScalar,
        ),
        provenance,
    )
end

function public_task_project()
    licence = LicenceIdentity(
        "PolyForm-Noncommercial-1.0.0",
        "PolyForm Noncommercial 1.0.0",
    )
    provenance = ProvenanceSource(
        ProjectId("source.general_multirate_task_platform"),
        "AIMORA-authored synthetic general multirate EMT task case",
        licence;
        source_version = "1.0.0",
    )
    metadata = ProjectMetadata(
        ObjectIdentity(ProjectId("project.general_multirate_task_platform")),
        "General Multirate EMT Task Platform",
        NamespaceId("aimora.cases"),
        v"1.0.0",
        DateTime(2026, 8, 12),
        provenance,
    )
    project = unsafe_project(
        metadata,
        SemanticSchemaRegistry(),
        si_unit_registry(),
        CanonicalRecord[],
    )
    return (; project, provenance)
end

function public_task_declarations()
    fixture = public_task_project()
    families = ControlTaskFamily[
        ProtectionControlTask,
        CarrierControlTask,
        ConverterControlTask,
        MechanicalControlTask,
        SourceControlTask,
        ThermalControlTask,
        InterfaceControlTask,
        UserDefinedControlTask,
    ]
    declarations = ControlTaskDeclaration[]
    for index in eachindex(TASK_PERIODS_US)
        family = families[mod1(index, length(families))]
        push!(declarations, ControlTaskDeclaration(
            ProjectId("general_task_$index"),
            family,
            public_task_time(0, fixture.provenance),
            public_task_time(TASK_PERIODS_US[index], fixture.provenance),
            public_task_time(TASK_PHASES_US[index], fixture.provenance),
            public_task_time(TASK_DELAYS_US[index], fixture.provenance);
            priority = index - 9,
            read_resources = index == 1 ?
                [ProjectId("general_task_input")] :
                [ProjectId("general_task_output_$(index - 1)")],
            write_resources = [ProjectId("general_task_output_$index")],
            predecessors = index == 1 ? ProjectId[] :
                [ProjectId("general_task_$(index - 1)")],
            invalidations = index == length(TASK_PERIODS_US) ? [
                InvalidateControlPowerHistory,
                InvalidateControlOutput,
            ] : ControlTaskInvalidation[],
        ))
    end
    return fixture.project, declarations
end

function public_task_scheduler(; fail_on_event_collision::Bool = false)
    project, declarations = public_task_declarations()
    specifications = EMTTaskSpec[emt_task_spec(project, declaration) for declaration in declarations]
    plan = emt_task_plan(
        specifications;
        start = emt_logical_time(0),
        stop = HORIZON,
    )
    tasks = ntuple(length(plan.entries)) do index
        state = PublicTaskState(
            Int(UInt8(plan.entries[index].spec.family)),
            index == 1 ? nothing : Symbol("GENERAL_TASK_OUTPUT_$(index - 1)"),
            Symbol("GENERAL_TASK_OUTPUT_$index"),
            0,
            fail_on_event_collision && index == 4 ? 3 : -1,
        )
        GeneralEMTTask(
            plan.entries[index],
            ReadPublicTask(),
            ComputePublicTask(),
            WritePublicTask();
            state,
            initial_output = 0.0,
        )
    end
    return GeneralEMTTaskScheduler(plan, tasks)
end

function public_task_workspace()
    parsed = AIMORA.DeckParser.parse_deck_file(CASE_DECK)
    workspace = EMTStudyWorkspace(prepare_emt_study(parsed; time_horizon = :deck))
    runtime = something(workspace.runtime.context.control_system_runtime)
    runtime.state.values[:GENERAL_TASK_INPUT] = 1.0
    for index in eachindex(TASK_PERIODS_US)
        runtime.state.values[Symbol("GENERAL_TASK_OUTPUT_$index")] = 0.0
    end
    return workspace
end

function public_task_event()
    return EMTHybridEventSurface(
        :general_task_input_step,
        PublicTaskEventValue(),
        ApplyPublicTaskEvent();
        repeatable = false,
        candidate_time = PublicTaskEventCandidate(),
    )
end

function public_task_integrator(; fail_on_event_collision::Bool = false)
    return configure_emt_hybrid_execution(
        public_task_workspace();
        event_surfaces = [public_task_event()],
        scheduler = public_task_scheduler(; fail_on_event_collision),
        include_device_events = false,
    )
end

function exact_trace_equal(left, right)
    return left.time_s == right.time_s &&
        left.voltage_pu == right.voltage_pu &&
        left.output_pu == right.output_pu &&
        left.node_maximum_values == right.node_maximum_values &&
        left.node_minimum_values == right.node_minimum_values &&
        left.output_maximum_values == right.output_maximum_values &&
        left.output_minimum_values == right.output_minimum_values
end

function run_public_task_case()
    integrator = public_task_integrator()
    for _ in 1:2
        advance_emt_hybrid_step!(integrator)
    end
    restarted = deepcopy(integrator)
    baseline_trace = evaluate_emt_hybrid_study!(integrator)
    restarted_trace = evaluate_emt_hybrid_study!(restarted)
    exact_trace_equal(baseline_trace, restarted_trace) || error(
        "general multirate task split restart changed the EMT trace",
    )
    integrator.scheduler.occurrences == restarted.scheduler.occurrences || error(
        "general multirate task split restart changed the exact occurrence trace",
    )
    result = general_task_scheduler_result(integrator.scheduler)
    restarted_result = general_task_scheduler_result(restarted.scheduler)
    result.deterministic_signature_sha256 == restarted_result.deterministic_signature_sha256 ||
        error("general multirate task split restart changed its deterministic signature")
    collision_occurrences = filter(
        occurrence -> occurrence.exact_instant == EVENT_INSTANT,
        result.occurrences,
    )
    collision_task_names = unique(getfield.(collision_occurrences, :task))
    length(collision_task_names) >= 6 || error(
        "public general-task event boundary did not exercise the declared task collision",
    )
    runtime = something(integrator.workspace.runtime.context.control_system_runtime)
    runtime.state.values[:GENERAL_TASK_INPUT] == 2.0 || error(
        "public general-task event did not precede due task reads",
    )
    maximum(abs, baseline_trace.voltage_pu) > 0.0 || error(
        "public general-task controlled source produced no EMT network response",
    )
    return (; integrator, trace = baseline_trace, result, collision_task_names)
end

function run_rollback_probe()
    integrator = public_task_integrator(fail_on_event_collision = true)
    while !integrator.completed
        try
            advance_emt_hybrid_step!(integrator)
        catch error
            error isa EMTTaskPlatformFailure || rethrow()
            error.code == :task_compute_failed || rethrow()
            error.instant == EVENT_INSTANT || error(
                "public general-task rollback probe failed at the wrong instant",
            )
            runtime = something(integrator.workspace.runtime.context.control_system_runtime)
            runtime.state.values[:GENERAL_TASK_INPUT] == 1.0 || error(
                "failed public task boundary did not restore the event-owned input",
            )
            all(
                occurrence -> occurrence.exact_instant != EVENT_INSTANT,
                integrator.scheduler.occurrences,
            ) || error("failed public task boundary published a partial occurrence")
            return error
        end
    end
    error("public general-task rollback probe did not fail at the event collision")
end

function main()
    AIMORA.require_solver()
    output_directory = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    accepted = run_public_task_case()
    rollback_failure = run_rollback_probe()
    stage_counts = Dict(
        stage => count(occurrence -> occurrence.stage == stage, accepted.result.occurrences)
        for stage in (
            EMTTaskReadStage,
            EMTTaskComputeStage,
            EMTTaskEnqueueStage,
            EMTTaskWriteStage,
            EMTTaskHoldStage,
        )
    )
    voltage_series = [
        String(accepted.trace.node_names[index]) =>
            vec(accepted.trace.voltage_pu[index, :])
        for index in eachindex(accepted.trace.node_names)
    ]
    csv_path = write_series_csv(
        joinpath(output_directory, "general_multirate_task_platform.csv"),
        "time_s",
        accepted.trace.time_s,
        voltage_series,
    )
    waveform_path = write_waveform_svg(
        joinpath(output_directory, "general_multirate_task_platform.svg"),
        accepted.trace.time_s,
        voltage_series;
        title="General Multirate EMT Task Platform",
        y_label="node voltage (pu)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "General Multirate EMT Task Platform",
        (
            accepted = accepted.result.accepted,
            task_family_count = length(unique(
                occurrence.family for occurrence in accepted.result.occurrences
            )),
            rational_period_phase_combinations = length(TASK_PERIODS_US),
            event_collision_time_s = Float64(EVENT_INSTANT),
            event_collision_task_count = length(accepted.collision_task_names),
            read_count = stage_counts[EMTTaskReadStage],
            compute_count = stage_counts[EMTTaskComputeStage],
            enqueue_count = stage_counts[EMTTaskEnqueueStage],
            write_count = stage_counts[EMTTaskWriteStage],
            hold_count = stage_counts[EMTTaskHoldStage],
            maximum_pending_depth = accepted.result.maximum_pending_depth,
            split_restart_exact = true,
            rollback_failure_code = rollback_failure.code,
            deterministic_signature_sha256 = accepted.result.deterministic_signature_sha256,
            synthetic_task_physics_only = true,
            external_protocol_or_realtime_claim = false,
        ),
    )
    println("CSV: ", csv_path)
    println("Waveform: ", waveform_path)
    println("Summary: ", summary_path)
end

main()
