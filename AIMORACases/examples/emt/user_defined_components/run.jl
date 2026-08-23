#!/usr/bin/env julia

using Printf
using SHA

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.Branches
using AIMORA.NativeExtensions
using AIMORA.Nodal
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal
using AIMORA.OVER16TimestepIntegration
using AIMORACases
using AIMORAProject
using .ExampleSupport

const TIMESTEP_S = 10.0e-6
const FINAL_TIME_S = 1.0e-3
const CONTROL_PERIOD_S = 100.0e-6
const CONTROL_DELAY_S = 20.0e-6
const INPUT_EVENT_TIME_S = 300.0e-6
const INITIAL_INPUT_A = 0.2
const EVENT_INPUT_A = 0.8
const SOURCE_SHUNT_CONDUCTANCE_S = 0.1
const SERIES_RESISTANCE_OHM = 2.0
const SERIES_INDUCTANCE_H = 2.0e-3
const CUBIC_CONDUCTANCE_S = 0.05
const CUBIC_COEFFICIENT_A_PER_V3 = 0.002

mutable struct UserDefinedComponentCaseOwner{C,E}
    control::C
    event::E
    timestep_s::Float64
    commanded_input_a::Float64
    event_applied::Bool
    localized_event_time_s::Float64
    event_probe_s::Float64
end

struct SampleUserDefinedControl end

function (::SampleUserDefinedControl)(
    owner::UserDefinedComponentCaseOwner,
    time_s::Real,
    _execution_index::Int,
)
    tick = round(Int, Float64(time_s) / owner.timestep_s)
    sample_extension_task!(
        owner.control,
        owner.commanded_input_a,
        tick,
        owner.timestep_s,
    )
    return nothing
end

struct ReleaseUserDefinedControl end

function (::ReleaseUserDefinedControl)(
    owner::UserDefinedComponentCaseOwner,
    time_s::Real,
    _execution_index::Int,
)
    release_extension_task_output!(
        owner.control,
        round(Int, Float64(time_s) / owner.timestep_s),
    )
    return nothing
end

struct UserDefinedCurrentSource{C}
    control::C
end

function (source::UserDefinedCurrentSource)(time_s::Real)
    return extension_source_value(source.control, time_s)
end

struct UserDefinedEventSurfaceValue end

function (::UserDefinedEventSurfaceValue)(owner::UserDefinedComponentCaseOwner)
    return extension_event_value(owner.event, owner.event_probe_s)
end

struct ApplyUserDefinedEvent end

function (::ApplyUserDefinedEvent)(owner::UserDefinedComponentCaseOwner, time_s::Real)
    accept_extension_event!(owner.event)
    owner.commanded_input_a = EVENT_INPUT_A
    owner.event_applied = true
    owner.localized_event_time_s = Float64(time_s)
    return nothing
end

struct UserDefinedEventRootEvaluator{E}
    event::E
end

function (evaluator::UserDefinedEventRootEvaluator)(time_s::Real)
    return extension_event_value(evaluator.event, time_s)
end

function public_case_provenance()
    licence = LicenceIdentity(
        "PolyForm-Noncommercial-1.0.0",
        "PolyForm Noncommercial 1.0.0",
    )
    return ProvenanceSource(
        ProjectId("source.public_user_defined_components"),
        "AIMORA-authored synthetic public native-extension example",
        licence;
        source_version = "1.0.0",
    )
end

function public_reusable_definition(provenance::ProvenanceSource)
    return ReusableDefinition(
        ObjectIdentity(ProjectId("definition.user_defined_components")),
        SemanticTypeId(
            NamespaceId("aimora.cases.extensions"),
            ProjectId("user_defined_components"),
            v"1.0.0",
        ),
        DefinitionParameterSpec[],
        DefinitionExternalPort[],
        DefinitionRecord[],
        CanonicalAsset[],
        SemanticGraphs(),
        DefinitionParameterBinding[],
        DefinitionInstance[],
        provenance,
    )
end

function public_project_declarations(registry::ExtensionRegistry)
    provenance = public_case_provenance()
    definition = public_reusable_definition(provenance)
    definition_reference = ProjectReference(
        ReferenceDefinition,
        definition.identity.id,
    )
    control = native_extension_declaration(
        PublicSampledSaturatingLag,
        ObjectIdentity(ProjectId("control.sampled_saturating_lag")),
        [ProjectReference(ReferenceControlBlock, ProjectId("control.input_current"))],
        [
            AssetProperty(FieldPath("control.gain"), parse_exact_decimal("1.0"), provenance),
            AssetProperty(FieldPath("control.time_constant_s"), parse_exact_decimal("0.5e-3"), provenance),
            AssetProperty(FieldPath("control.period_s"), parse_exact_decimal("100e-6"), provenance),
            AssetProperty(FieldPath("control.delay_s"), parse_exact_decimal("20e-6"), provenance),
        ],
        provenance;
        reusable_definition = definition_reference,
    )
    cubic = native_extension_declaration(
        PublicCubicCurrentBranch,
        ObjectIdentity(ProjectId("device.passive_cubic_branch")),
        [
            ProjectReference(ReferenceNode, ProjectId("node.load")),
            ProjectReference(ReferenceNode, ProjectId("node.ground")),
        ],
        [
            AssetProperty(FieldPath("cubic.linear_conductance_s"), parse_exact_decimal("0.05"), provenance),
            AssetProperty(FieldPath("cubic.coefficient_a_per_v3"), parse_exact_decimal("0.002"), provenance),
        ],
        provenance,
    )
    series_rl = native_extension_declaration(
        PublicSeriesRLCompanion,
        ObjectIdentity(ProjectId("device.series_rl_companion")),
        [
            ProjectReference(ReferenceNode, ProjectId("node.source")),
            ProjectReference(ReferenceNode, ProjectId("node.load")),
        ],
        [
            AssetProperty(FieldPath("series_rl.resistance_ohm"), parse_exact_decimal("2.0"), provenance),
            AssetProperty(FieldPath("series_rl.inductance_h"), parse_exact_decimal("2e-3"), provenance),
        ],
        provenance;
        reusable_definition = definition_reference,
    )
    declarations = (control, cubic, series_rl)
    for declaration in declarations
        resolve_extension(registry, declaration)
    end
    project_sha256 = bytes2hex(sha256(
        join(extension_declaration_hash.(declarations), '\n') * "\n" *
        definition.identity.id.value * "\n" * string(definition.definition_type.version) * "\n",
    ))
    return (definition = definition, declarations = declarations, sha256 = project_sha256)
end

function construct_public_case(; timestep_s::Float64 = TIMESTEP_S)
    isfinite(timestep_s) && 1.0e-6 <= timestep_s <= 1.0e-3 || throw(ArgumentError(
        "public extension case timestep must be finite and within 1 us to 1 ms",
    ))
    control_period_ticks = round(Int, CONTROL_PERIOD_S / timestep_s)
    control_delay_ticks = round(Int, CONTROL_DELAY_S / timestep_s)
    control_period_ticks * timestep_s == CONTROL_PERIOD_S || throw(ArgumentError(
        "public extension control period must be an exact timestep multiple",
    ))
    control_delay_ticks * timestep_s == CONTROL_DELAY_S || throw(ArgumentError(
        "public extension control delay must be an exact timestep multiple",
    ))
    registry = native_extension_registry()
    project = public_project_declarations(registry)
    control = construct_extension(
        registry,
        extension_identity(PublicSampledSaturatingLag),
        1.0,
        0.5e-3,
        0.0,
        1.0,
        control_period_ticks;
        delay_ticks = control_delay_ticks,
    )
    event = DirectedExtensionEvent(
        :time_s,
        INPUT_EVENT_TIME_S;
        direction = :rising,
        tolerance = 1.0e-12,
        priority = -10,
        maximum_occurrences = 1,
    )
    owner = UserDefinedComponentCaseOwner(
        control,
        event,
        timestep_s,
        INITIAL_INPUT_A,
        false,
        NaN,
        0.0,
    )
    series_rl = construct_extension(
        registry,
        extension_identity(PublicSeriesRLCompanion),
        1,
        2,
        SERIES_RESISTANCE_OHM,
        SERIES_INDUCTANCE_H,
    )
    cubic = construct_extension(
        registry,
        extension_identity(PublicCubicCurrentBranch),
        2,
        0,
        CUBIC_CONDUCTANCE_S,
        CUBIC_COEFFICIENT_A_PER_V3,
    )
    linear = NodalSystem(
        2,
        [
            series_rl,
            ConductanceBranch(1, 0, SOURCE_SHUNT_CONDUCTANCE_S),
            CurrentInjection(1, UserDefinedCurrentSource(control)),
        ],
    )
    system = NonlinearNodalSystem(
        linear,
        [cubic];
        scales = NonlinearNetworkScales(
            [5.0, 5.0],
            [1.0, 1.0],
            Float64[],
            Float64[],
        ),
    )
    sample_task = ExactSampledTask(
        :sample_extension_control,
        CONTROL_PERIOD_S,
        SampleUserDefinedControl();
        tick_s = timestep_s,
        priority = 0,
    )
    release_task = ExactSampledTask(
        :release_extension_control,
        CONTROL_PERIOD_S,
        ReleaseUserDefinedControl();
        tick_s = timestep_s,
        first_time_s = CONTROL_DELAY_S,
        priority = -1,
    )
    scheduler = ExactSampledTaskScheduler(
        timestep_s;
        tasks = [release_task, sample_task],
    )
    surface = HybridEventSurface(
        :user_input_threshold,
        UserDefinedEventSurfaceValue(),
        ApplyUserDefinedEvent();
        direction = HYBRID_EVENT_RISING,
        priority = -10,
        topology_invalidating = false,
        repeatable = false,
    )
    policy = HybridEventPolicy(
        root_time_tolerance_s = 1.0e-12,
        root_value_tolerance = 1.0e-15,
        simultaneity_tolerance_s = 1.0e-12,
    )
    return (
        registry = registry,
        project = project,
        owner = owner,
        series_rl = series_rl,
        cubic = cubic,
        system = system,
        scheduler = scheduler,
        sample_task = sample_task,
        release_task = release_task,
        surface = surface,
        policy = policy,
    )
end

function process_case_boundary!(state, boundary_time_s::Float64)
    if !state.owner.event_applied && boundary_time_s > 0.0
        left_time_s = boundary_time_s - state.owner.timestep_s
        left_value = extension_event_value(state.owner.event, left_time_s)
        state.owner.event_probe_s = boundary_time_s
        right_value = hybrid_event_value(state.surface, state.owner)
        bracket = hybrid_event_bracket(
            state.surface.direction,
            left_time_s,
            left_value,
            boundary_time_s,
            right_value,
            state.policy,
        )
        if bracket !== nothing
            root = localize_hybrid_event!(
                UserDefinedEventRootEvaluator(state.owner.event),
                state.surface.direction,
                bracket,
                state.policy,
            )
            root.converged || error("public extension event root did not converge")
            apply_hybrid_event!(state.surface, state.owner, root.time_s)
        end
    end
    run_due_sampled_tasks!(state.scheduler, state.owner, boundary_time_s)
    return nothing
end

function advance_case_interval!(state, step_index::Int)
    timestep_s = state.owner.timestep_s
    boundary_time_s = (step_index - 1) * timestep_s
    process_case_boundary!(state, boundary_time_s)
    accepted_time_s = step_index * timestep_s
    result = advance_nonlinear_step!(state.system, accepted_time_s, timestep_s)
    result.accepted || error(
        "public extension network failed at step $step_index: $(result.failure)",
    )
    voltages = result.voltage_v
    cubic_outputs = extension_outputs(
        state.cubic,
        [voltages[2], 0.0],
        accepted_time_s,
    )
    return (
        time_s = accepted_time_s,
        source_voltage_v = voltages[1],
        load_voltage_v = voltages[2],
        series_current_a = state.series_rl.last_current_a,
        control_output_a = extension_source_value(state.owner.control, accepted_time_s),
        cubic_power_w = cubic_outputs[2].value,
        maximum_kcl_residual_a = result.diagnostics.maximum_kcl_residual_a,
    )
end

function case_checkpoint(state)
    return (
        network = nonlinear_nodal_checkpoint(state.system),
        control = extension_checkpoint(state.owner.control),
        sampled_tasks = sampled_task_checkpoint.(state.scheduler.tasks),
        sampled_occurrence_count = length(state.scheduler.occurrences),
        event_occurrence_count = state.owner.event.occurrence_count,
        commanded_input_a = state.owner.commanded_input_a,
        event_applied = state.owner.event_applied,
        localized_event_time_s = state.owner.localized_event_time_s,
        event_probe_s = state.owner.event_probe_s,
    )
end

function restore_case_checkpoint!(state, checkpoint)
    restore_nonlinear_nodal_checkpoint!(state.system, checkpoint.network)
    restore_extension_checkpoint!(state.owner.control, checkpoint.control)
    for (task, task_checkpoint) in zip(state.scheduler.tasks, checkpoint.sampled_tasks)
        restore_sampled_task_checkpoint!(task, task_checkpoint)
    end
    resize!(state.scheduler.occurrences, checkpoint.sampled_occurrence_count)
    state.owner.event.occurrence_count = checkpoint.event_occurrence_count
    state.owner.commanded_input_a = checkpoint.commanded_input_a
    state.owner.event_applied = checkpoint.event_applied
    state.owner.localized_event_time_s = checkpoint.localized_event_time_s
    state.owner.event_probe_s = checkpoint.event_probe_s
    return state
end

function component_execution_results(state, final_time_s::Float64, maximum_kcl_residual_a::Float64)
    control_outputs = extension_outputs(state.owner.control, final_time_s)
    cubic_outputs = extension_outputs(
        state.cubic,
        [nonlinear_linear_system(state.system).v[2], 0.0],
        final_time_s,
    )
    series_outputs = extension_outputs(state.series_rl, final_time_s)
    control_checkpoint = extension_checkpoint(state.owner.control)
    cubic_checkpoint = extension_checkpoint(state.cubic)
    series_checkpoint = extension_checkpoint(state.series_rl)
    control_result = ExtensionExecutionResult(
        true,
        extension_contract(state.owner.control),
        (1,),
        state.project.sha256,
        control_outputs,
        state.owner.event.occurrence_count,
        state.owner.control.sample_count,
        control_checkpoint.state_sha256,
        (
            localized_event_time_s = state.owner.localized_event_time_s,
            sample_count = state.owner.control.sample_count,
            write_count = state.owner.control.write_count,
        ),
        ("A", "s", "exact integer scheduler ticks"),
    )
    cubic_result = ExtensionExecutionResult(
        true,
        extension_contract(state.cubic),
        (2, 0),
        state.project.sha256,
        cubic_outputs,
        0,
        0,
        cubic_checkpoint.state_sha256,
        (maximum_kcl_residual_a = maximum_kcl_residual_a,),
        ("V", "A", "S", "A/V^3"),
    )
    series_result = ExtensionExecutionResult(
        true,
        extension_contract(state.series_rl),
        (1, 2),
        state.project.sha256,
        series_outputs,
        0,
        0,
        series_checkpoint.state_sha256,
        (
            previous_voltage_v = state.series_rl.previous_voltage_v,
            previous_current_a = state.series_rl.previous_current_a,
        ),
        ("V", "A", "ohm", "H", "s"),
    )
    validate_extension_result(
        control_result,
        extension_contract(state.owner.control),
        state.project.sha256,
        control_checkpoint.state_sha256,
        ("declared_control_unit", "declared_control_unit"),
    )
    validate_extension_result(
        cubic_result,
        extension_contract(state.cubic),
        state.project.sha256,
        cubic_checkpoint.state_sha256,
        ("A", "W"),
    )
    validate_extension_result(
        series_result,
        extension_contract(state.series_rl),
        state.project.sha256,
        series_checkpoint.state_sha256,
        ("A", "J", "W"),
    )
    return (control_result, cubic_result, series_result)
end

function run_public_case(
    ;
    exercise_restore::Bool,
    timestep_s::Float64 = TIMESTEP_S,
    final_time_s::Float64 = FINAL_TIME_S,
)
    isfinite(final_time_s) && final_time_s > 0.0 || throw(ArgumentError(
        "public extension case final time must be finite and positive",
    ))
    step_count = round(Int, final_time_s / timestep_s)
    step_count * timestep_s == final_time_s || throw(ArgumentError(
        "public extension case final time must be an exact timestep multiple",
    ))
    step_count <= 1_000 || throw(ArgumentError(
        "public extension case is qualified for at most 1,000 accepted steps",
    ))
    state = construct_public_case(; timestep_s)
    time_s = collect(0:step_count) .* timestep_s
    source_voltage_v = zeros(Float64, step_count + 1)
    load_voltage_v = zeros(Float64, step_count + 1)
    series_current_a = zeros(Float64, step_count + 1)
    control_output_a = zeros(Float64, step_count + 1)
    cubic_power_w = zeros(Float64, step_count + 1)
    maximum_kcl_residual_a = 0.0
    restored_probe = false
    for step_index in 1:step_count
        record = advance_case_interval!(state, step_index)
        output_index = step_index + 1
        source_voltage_v[output_index] = record.source_voltage_v
        load_voltage_v[output_index] = record.load_voltage_v
        series_current_a[output_index] = record.series_current_a
        control_output_a[output_index] = record.control_output_a
        cubic_power_w[output_index] = record.cubic_power_w
        maximum_kcl_residual_a = max(
            maximum_kcl_residual_a,
            record.maximum_kcl_residual_a,
        )
        checkpoint_step = round(Int, 0.5 * final_time_s / timestep_s)
        if exercise_restore && step_index == checkpoint_step
            checkpoint = case_checkpoint(state)
            advance_case_interval!(state, step_index + 1)
            restore_case_checkpoint!(state, checkpoint)
            restored_probe = true
        end
    end
    execution_results = component_execution_results(
        state,
        final_time_s,
        maximum_kcl_residual_a,
    )
    deterministic_sha256 = extension_state_signature((
        project_sha256 = state.project.sha256,
        time_s = time_s,
        source_voltage_v = source_voltage_v,
        load_voltage_v = load_voltage_v,
        series_current_a = series_current_a,
        control_output_a = control_output_a,
        cubic_power_w = cubic_power_w,
        component_results = getfield.(execution_results, :deterministic_sha256),
        scheduler_occurrences = state.scheduler.occurrences,
        event_time_s = state.owner.localized_event_time_s,
    ))
    return (
        state = state,
        time_s = time_s,
        source_voltage_v = source_voltage_v,
        load_voltage_v = load_voltage_v,
        series_current_a = series_current_a,
        control_output_a = control_output_a,
        cubic_power_w = cubic_power_w,
        maximum_kcl_residual_a = maximum_kcl_residual_a,
        execution_results = execution_results,
        deterministic_sha256 = deterministic_sha256,
        restored_probe = restored_probe,
    )
end

function bitwise_equal(left::AbstractArray{Float64}, right::AbstractArray{Float64})
    return reinterpret(UInt64, left) == reinterpret(UInt64, right)
end

function write_result_contract(path::AbstractString, results)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "semantic_type,accepted,representation,fidelity,terminals,event_cursor,task_cursor,output_cursor,project_sha256,checkpoint_sha256,deterministic_sha256")
        for result in results
            @printf(
                io,
                "%s,%s,%s,%s,%s,%d,%d,%d,%s,%s,%s\n",
                result.identity.semantic_type,
                result.accepted,
                result.representation,
                result.fidelity,
                join(result.terminal_nodes, ";"),
                result.event_cursor,
                result.task_cursor,
                result.output_cursor,
                result.project_sha256,
                result.checkpoint_sha256,
                result.deterministic_sha256,
            )
        end
    end
    return abspath(path)
end

function main(arguments::Vector{String})
    output_directory = artifact_directory(
        arguments,
        joinpath(@__DIR__, "outputs"),
    )
    baseline = run_public_case(exercise_restore = false)
    restarted = run_public_case(exercise_restore = true)
    restarted.restored_probe || error("public extension restart probe was not exercised")
    for name in (
        :time_s,
        :source_voltage_v,
        :load_voltage_v,
        :series_current_a,
        :control_output_a,
        :cubic_power_w,
    )
        bitwise_equal(getfield(baseline, name), getfield(restarted, name)) ||
            error("public extension restart changed $name")
    end
    baseline.deterministic_sha256 == restarted.deterministic_sha256 || error(
        "public extension deterministic signature changed across restart",
    )
    baseline.state.owner.event_applied || error("public extension event did not execute")
    baseline.state.owner.event.occurrence_count == 1 || error(
        "public extension event did not execute exactly once",
    )
    abs(baseline.state.owner.localized_event_time_s - INPUT_EVENT_TIME_S) <= 1.0e-12 ||
        error("public extension event was not localized to its declared threshold")
    all(result -> result.accepted, baseline.execution_results) || error(
        "public extension typed execution result reported a failure",
    )
    minimum(baseline.cubic_power_w) >= -eps(Float64) || error(
        "public cubic extension violated passivity",
    )

    write_series_csv(
        joinpath(output_directory, "waveform.csv"),
        "time_s",
        baseline.time_s,
        [
            "source_voltage_v" => baseline.source_voltage_v,
            "load_voltage_v" => baseline.load_voltage_v,
            "series_current_a" => baseline.series_current_a,
            "control_output_a" => baseline.control_output_a,
            "cubic_power_w" => baseline.cubic_power_w,
        ],
    )
    write_waveform_svg(
        joinpath(output_directory, "waveform.svg"),
        baseline.time_s,
        [
            "source voltage (V)" => baseline.source_voltage_v,
            "load voltage (V)" => baseline.load_voltage_v,
            "series current (A)" => baseline.series_current_a,
            "control output (A)" => baseline.control_output_a,
        ];
        title = "Native User-Defined Component Coupled Response",
        x_label = "time (s)",
        y_label = "declared SI value",
    )
    write_result_contract(
        joinpath(output_directory, "result_contract.csv"),
        baseline.execution_results,
    )
    write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Native User-Defined Components",
        (
            project_sha256 = baseline.state.project.sha256,
            deterministic_sha256 = baseline.deterministic_sha256,
            registered_component_count = length(registered_extension_identities(baseline.state.registry)),
            reusable_definition = baseline.state.project.definition.identity.id.value,
            accepted_step_count = length(baseline.time_s) - 1,
            localized_event_time_s = baseline.state.owner.localized_event_time_s,
            event_occurrence_count = baseline.state.owner.event.occurrence_count,
            sampled_task_occurrence_count = length(baseline.state.scheduler.occurrences),
            control_sample_count = baseline.state.owner.control.sample_count,
            control_write_count = baseline.state.owner.control.write_count,
            maximum_kcl_residual_a = baseline.maximum_kcl_residual_a,
            minimum_cubic_absorbed_power_w = minimum(baseline.cubic_power_w),
            checkpoint_restart_bitwise_equal = true,
            explicit_exclusions = "ATP MODELS, Type-94, PSCAD, FMI, Modelica, native ABI, manufacturer accuracy, standard conformance, and certification",
        ),
    )
    println("native user-defined component example passed: $(baseline.deterministic_sha256)")
    return nothing
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
