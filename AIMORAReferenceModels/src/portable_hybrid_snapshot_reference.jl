"""One callback-free exact action-task occurrence decoded by the independent portable reader."""
struct IndependentPortableHybridTaskOccurrence
    name::String
    time_s::Float64
    tick::Int
    priority::Int
    execution_index::Int
end

"""One callback-free hybrid event occurrence decoded by the independent portable reader."""
struct IndependentPortableHybridEventOccurrence
    name::String
    time_s::Float64
    value::Float64
    priority::Int
    topology_invalidating::Bool
    root_iteration_count::Int
    root_bracket_width_s::Float64
end

"""Independent inventory, clock, task, and event interpretation of one hybrid snapshot."""
struct IndependentPortableHybridReference
    public_inventory_signature_sha256::String
    hybrid_inventory_signature_sha256::String
    accepted_step::Int
    accepted_time_s::Float64
    next_step_index::Int
    next_time_s::Float64
    horizon_step_count::Int
    horizon_time_s::Float64
    task_program_signature_sha256::String
    event_program_signature_sha256::String
    task_occurrences::Vector{IndependentPortableHybridTaskOccurrence}
    future_task_occurrences::Vector{IndependentPortableHybridTaskOccurrence}
    event_occurrences::Vector{IndependentPortableHybridEventOccurrence}
    surface_names::Vector{String}
    surface_fired::Vector{Bool}
    deterministic_signature_sha256::String
end

function _independent_reference_record_fields(
    record,
    schema::AbstractString,
    required_fields,
)
    record isa IndependentPortableRecord || throw(ArgumentError(
        "independent portable $schema value is not a record",
    ))
    record.schema_id == schema || throw(ArgumentError(
        "independent portable record expected $schema but found $(record.schema_id)",
    ))
    fields = Dict{String,Any}(record.fields)
    Set(keys(fields)) == Set(String.(required_fields)) || throw(ArgumentError(
        "independent portable $schema fields are incomplete or unknown",
    ))
    return fields
end

function _independent_reference_integer(value, label::AbstractString)
    value isa Integer || throw(ArgumentError(
        "independent portable $label is not an integer",
    ))
    typemin(Int) <= value <= typemax(Int) || throw(ArgumentError(
        "independent portable $label exceeds the host integer range",
    ))
    return Int(value)
end

function _independent_reference_float(value, label::AbstractString)
    value isa Real || throw(ArgumentError(
        "independent portable $label is not a real scalar",
    ))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError(
        "independent portable $label is nonfinite",
    ))
    return result
end

function _independent_reference_time_equal(left::Float64, right::Float64)
    scale = max(abs(left), abs(right), floatmin(Float64))
    return abs(left - right) <= 32.0 * eps(scale)
end

function _independent_reference_scalar_count(value)
    if value === nothing || value isa AbstractString || value isa AbstractVector{UInt8}
        return 0
    elseif value isa Number || value isa Bool
        return 1
    elseif value isa IndependentPortableArray
        return isempty(value.shape) ? 1 : prod(value.shape; init = 1)
    elseif value isa IndependentPortableRecord
        return sum(
            _independent_reference_scalar_count(last(field)) for field in value.fields;
            init = 0,
        )
    elseif value isa AbstractVector || value isa Tuple
        return sum(_independent_reference_scalar_count(item) for item in value; init = 0)
    end
    throw(ArgumentError(
        "independent portable state value $(typeof(value)) cannot be counted",
    ))
end

function _independent_reference_state_inventory(record)
    inventory = _independent_reference_record_fields(
        record,
        "aimora.snapshot.state_inventory.v1",
        ["fields", "scalar_count", "signature_sha256"],
    )
    encoded_fields = inventory["fields"]
    encoded_fields isa AbstractVector || throw(ArgumentError(
        "independent portable state inventory field list is not a sequence",
    ))
    parsed = Dict{String,NamedTuple}()
    previous_identity = ""
    for encoded_field in encoded_fields
        field = _independent_reference_record_fields(
            encoded_field,
            "aimora.snapshot.state_field.v1",
            ["axes", "family", "identity", "owner", "unit", "value"],
        )
        identity = String(field["identity"])
        isempty(previous_identity) || previous_identity < identity || throw(ArgumentError(
            "independent portable state fields are not in canonical identity order",
        ))
        previous_identity = identity
        haskey(parsed, identity) && throw(ArgumentError(
            "independent portable state inventory repeats $identity",
        ))
        axes = field["axes"]
        axes isa AbstractVector && all(axis -> axis isa AbstractString, axes) ||
            throw(ArgumentError("independent portable state axes have the wrong type"))
        parsed[identity] = (
            owner = String(field["owner"]),
            family = String(field["family"]),
            unit = String(field["unit"]),
            axes = String[String(axis) for axis in axes],
            value = field["value"],
        )
    end
    scalar_count = sum(
        _independent_reference_scalar_count(field.value) for field in values(parsed);
        init = 0,
    )
    scalar_count == _independent_reference_integer(
        inventory["scalar_count"],
        "state scalar count",
    ) || throw(ArgumentError(
        "independent portable state scalar count does not match its fields",
    ))
    unsigned_count = UInt64(scalar_count)
    unsigned_count == inventory["scalar_count"] || throw(ArgumentError(
        "independent portable state scalar count is not canonically unsigned",
    ))
    provisional = IndependentPortableRecord(
        "aimora.snapshot.state_inventory.v1",
        Pair{String,Any}[
            "fields" => encoded_fields,
            "scalar_count" => unsigned_count,
        ],
    )
    signature = bytes2hex(sha256(_independent_value_bytes(provisional)))
    signature == inventory["signature_sha256"] || throw(ArgumentError(
        "independent portable state inventory signature failed",
    ))
    return parsed, signature
end

function _independent_reference_section(snapshot, identity::AbstractString)
    matches = filter(section -> section.identity == identity, snapshot.sections)
    length(matches) == 1 || throw(ArgumentError(
        "independent portable snapshot requires exactly one $identity section",
    ))
    section = only(matches)
    section.version_major == 1 && section.version_minor == 0 || throw(ArgumentError(
        "independent portable $identity section version is unsupported",
    ))
    section.visibility == :public || throw(ArgumentError(
        "independent portable $identity section must be public",
    ))
    return section
end

function _independent_reference_state_field(
    fields,
    identity::AbstractString,
    owner::AbstractString,
    family::AbstractString,
    unit::AbstractString,
)
    haskey(fields, identity) || throw(ArgumentError(
        "independent portable state omits $identity",
    ))
    field = fields[identity]
    field.owner == owner && field.family == family && field.unit == unit ||
        throw(ArgumentError(
            "independent portable state ownership changed for $identity",
        ))
    return field.value
end

function _independent_reference_task_occurrence(record)
    fields = _independent_reference_record_fields(
        record,
        "aimora.emt.exact_task_occurrence.v1",
        ["execution_index", "name", "priority", "tick", "time_s"],
    )
    return IndependentPortableHybridTaskOccurrence(
        String(fields["name"]),
        _independent_reference_float(fields["time_s"], "task occurrence time"),
        _independent_reference_integer(fields["tick"], "task occurrence tick"),
        _independent_reference_integer(fields["priority"], "task occurrence priority"),
        _independent_reference_integer(
            fields["execution_index"],
            "task occurrence execution index",
        ),
    )
end

function _independent_reference_action_task(record)
    fields = _independent_reference_record_fields(
        record,
        "aimora.emt.exact_action_task.v1",
        [
            "execution_count", "last_execution_tick", "name", "next_tick",
            "period_ticks", "power_history_invalidating", "priority", "tick_s",
        ],
    )
    fields["power_history_invalidating"] isa Bool || throw(ArgumentError(
        "independent portable task invalidation state is not Boolean",
    ))
    return (
        name = String(fields["name"]),
        tick_s = _independent_reference_float(fields["tick_s"], "task tick"),
        period_ticks = _independent_reference_integer(
            fields["period_ticks"],
            "task period ticks",
        ),
        next_tick = _independent_reference_integer(fields["next_tick"], "task next tick"),
        priority = _independent_reference_integer(fields["priority"], "task priority"),
        execution_count = _independent_reference_integer(
            fields["execution_count"],
            "task execution count",
        ),
        last_execution_tick = _independent_reference_integer(
            fields["last_execution_tick"],
            "task last execution tick",
        ),
    )
end

function _independent_reference_event_occurrence(record)
    fields = _independent_reference_record_fields(
        record,
        "aimora.emt.hybrid_occurrence.v1",
        [
            "name", "priority", "root_bracket_width_s", "root_iteration_count",
            "time_s", "topology_invalidating", "value",
        ],
    )
    fields["topology_invalidating"] isa Bool || throw(ArgumentError(
        "independent portable event topology state is not Boolean",
    ))
    width = _independent_reference_float(
        fields["root_bracket_width_s"],
        "event root bracket width",
    )
    width >= 0.0 || throw(ArgumentError(
        "independent portable event root bracket width is negative",
    ))
    return IndependentPortableHybridEventOccurrence(
        String(fields["name"]),
        _independent_reference_float(fields["time_s"], "event occurrence time"),
        _independent_reference_float(fields["value"], "event occurrence value"),
        _independent_reference_integer(fields["priority"], "event occurrence priority"),
        fields["topology_invalidating"],
        _independent_reference_integer(
            fields["root_iteration_count"],
            "event root iteration count",
        ),
        width,
    )
end

function _independent_reference_surface(record)
    fields = _independent_reference_record_fields(
        record,
        "aimora.emt.hybrid_surface.v1",
        [
            "candidate_is_event", "direction", "name", "priority", "repeatable",
            "topology_invalidating",
        ],
    )
    all(
        fields[name] isa Bool
        for name in ("candidate_is_event", "repeatable", "topology_invalidating")
    ) || throw(ArgumentError(
        "independent portable hybrid surface flags are not Boolean",
    ))
    direction = _independent_reference_integer(fields["direction"], "surface direction")
    direction in (-1, 0, 1) || throw(ArgumentError(
        "independent portable hybrid surface direction is unsupported",
    ))
    return (
        name = String(fields["name"]),
        repeatable = fields["repeatable"],
    )
end

function _independent_reference_signature(values)
    record = IndependentPortableRecord(
        "aimora.reference.hybrid_snapshot_interpretation.v1",
        Pair{String,Any}[
            "accepted_step" => values.accepted_step,
            "accepted_time_s" => values.accepted_time_s,
            "event_occurrences" => IndependentPortableRecord[
                IndependentPortableRecord(
                    "aimora.reference.hybrid_event_occurrence.v1",
                    Pair{String,Any}[
                        "name" => occurrence.name,
                        "time_s" => occurrence.time_s,
                    ],
                ) for occurrence in values.event_occurrences
            ],
            "future_task_occurrences" => IndependentPortableRecord[
                IndependentPortableRecord(
                    "aimora.reference.hybrid_task_occurrence.v1",
                    Pair{String,Any}[
                        "execution_index" => occurrence.execution_index,
                        "name" => occurrence.name,
                        "tick" => occurrence.tick,
                        "time_s" => occurrence.time_s,
                    ],
                ) for occurrence in values.future_task_occurrences
            ],
            "hybrid_inventory_signature_sha256" =>
                values.hybrid_inventory_signature_sha256,
            "public_inventory_signature_sha256" =>
                values.public_inventory_signature_sha256,
        ],
    )
    return bytes2hex(sha256(_independent_value_bytes(record)))
end

"""
    independent_portable_hybrid_reference(snapshot; task_program_signature_sha256,
        event_program_signature_sha256)

Decode and independently validate one canonical hybrid snapshot containing an
exact action-task scheduler. The formulation verifies both state-inventory
signatures, public/hybrid clocks, external callback-program identities, task
calendar recurrence, event/surface consistency, and predicts every remaining
task occurrence through the stored fixed-step horizon without importing AIMORA
production encoding, scheduler, event, or restore code.
"""
function independent_portable_hybrid_reference(
    snapshot::IndependentPortableSnapshot;
    task_program_signature_sha256::AbstractString,
    event_program_signature_sha256::AbstractString,
)
    public_section = _independent_reference_section(snapshot, "emt.public_state")
    hybrid_section = _independent_reference_section(snapshot, "emt.hybrid_state")
    public_fields, public_signature = _independent_reference_state_inventory(
        public_section.value,
    )
    hybrid_fields, hybrid_signature = _independent_reference_state_inventory(
        hybrid_section.value,
    )

    scheduler_owner = "emt.task_scheduler"
    hybrid_owner = "emt.hybrid_execution"
    required_scheduler = Set((
        "scheduler.adapter",
        "scheduler.kind",
        "scheduler.last_run_power_history_invalidating",
        "scheduler.occurrences",
        "scheduler.origin",
        "scheduler.program_signature",
        "scheduler.retain_occurrences",
        "scheduler.tasks",
        "scheduler.tick",
    ))
    required_hybrid = Set((
        "hybrid.accepted_step",
        "hybrid.accepted_interval_count",
        "hybrid.active_global_endpoint",
        "hybrid.completed",
        "hybrid.completed_global_step_count",
        "hybrid.evaluation_recorded",
        "hybrid.event_program_signature",
        "hybrid.initialized",
        "hybrid.last_global_step_event_count",
        "hybrid.localized_root_count",
        "hybrid.nominal_timestep",
        "hybrid.occurrences",
        "hybrid.policy.maximum_events_per_step",
        "hybrid.policy.maximum_root_iterations",
        "hybrid.policy.minimum_progress",
        "hybrid.policy.root_time_tolerance",
        "hybrid.policy.root_value_tolerance",
        "hybrid.policy.simultaneity_tolerance",
        "hybrid.provisional_interval_count",
        "hybrid.surface_fired",
        "hybrid.surfaces",
        "hybrid.topology_invalidation_count",
        "hybrid.transaction.capture_count",
        "hybrid.transaction.commit_count",
        "hybrid.transaction.restore_count",
        "hybrid.workspace_step_index",
        "hybrid.workspace_time",
    ))
    actual_scheduler = Set(identity for identity in keys(hybrid_fields) if startswith(identity, "scheduler."))
    actual_hybrid = Set(identity for identity in keys(hybrid_fields) if startswith(identity, "hybrid."))
    actual_scheduler == required_scheduler || throw(ArgumentError(
        "independent portable exact scheduler inventory is incomplete or unknown",
    ))
    actual_hybrid == required_hybrid || throw(ArgumentError(
        "independent portable hybrid inventory is incomplete or unknown",
    ))
    length(hybrid_fields) == length(required_scheduler) + length(required_hybrid) ||
        throw(ArgumentError("independent portable hybrid inventory has an unknown owner"))

    _independent_reference_state_field(
        hybrid_fields,
        "scheduler.adapter",
        scheduler_owner,
        "checkpoint",
        "1",
    ) === false || throw(ArgumentError(
        "independent portable hybrid reference requires the exact scheduler, not an adapter",
    ))
    _independent_reference_state_field(
        hybrid_fields,
        "scheduler.kind",
        scheduler_owner,
        "checkpoint",
        "1",
    ) == "exact_sampled" || throw(ArgumentError(
        "independent portable hybrid scheduler kind is unsupported",
    ))
    task_signature = String(_independent_reference_state_field(
        hybrid_fields,
        "scheduler.program_signature",
        scheduler_owner,
        "checkpoint",
        "1",
    ))
    event_signature = String(_independent_reference_state_field(
        hybrid_fields,
        "hybrid.event_program_signature",
        hybrid_owner,
        "checkpoint",
        "1",
    ))
    task_signature == task_program_signature_sha256 || throw(ArgumentError(
        "independent portable task callback-program identity changed",
    ))
    event_signature == event_program_signature_sha256 || throw(ArgumentError(
        "independent portable event callback-program identity changed",
    ))

    accepted_step = _independent_reference_integer(
        _independent_reference_state_field(
            hybrid_fields,
            "hybrid.accepted_step",
            hybrid_owner,
            "scheduler",
            "1",
        ),
        "hybrid accepted step",
    )
    accepted_time_s = _independent_reference_float(
        _independent_reference_state_field(
            hybrid_fields,
            "hybrid.active_global_endpoint",
            hybrid_owner,
            "scheduler",
            "s",
        ),
        "hybrid accepted endpoint",
    )
    next_step_index = _independent_reference_integer(
        _independent_reference_state_field(
            hybrid_fields,
            "hybrid.workspace_step_index",
            hybrid_owner,
            "checkpoint",
            "1",
        ),
        "hybrid next step index",
    )
    next_time_s = _independent_reference_float(
        _independent_reference_state_field(
            hybrid_fields,
            "hybrid.workspace_time",
            hybrid_owner,
            "checkpoint",
            "s",
        ),
        "hybrid next time",
    )
    timestep_s = _independent_reference_float(
        _independent_reference_state_field(
            hybrid_fields,
            "hybrid.nominal_timestep",
            hybrid_owner,
            "checkpoint",
            "s",
        ),
        "hybrid nominal timestep",
    )
    timestep_s > 0.0 || throw(ArgumentError(
        "independent portable hybrid timestep must be positive",
    ))
    horizon_step_count = _independent_reference_integer(
        _independent_reference_state_field(
            public_fields,
            "execution.horizon_step_count",
            "emt.execution",
            "checkpoint",
            "1",
        ),
        "workspace horizon step count",
    )
    horizon_time_s = _independent_reference_float(
        _independent_reference_state_field(
            public_fields,
            "execution.horizon",
            "emt.execution",
            "checkpoint",
            "s",
        ),
        "workspace horizon time",
    )
    public_accepted_step = _independent_reference_integer(
        _independent_reference_state_field(
            public_fields,
            "execution.accepted_step",
            "emt.execution",
            "scheduler",
            "1",
        ),
        "workspace accepted step",
    )
    public_accepted_time_s = _independent_reference_float(
        _independent_reference_state_field(
            public_fields,
            "execution.accepted_time",
            "emt.execution",
            "scheduler",
            "s",
        ),
        "workspace accepted time",
    )
    public_next_step = _independent_reference_integer(
        _independent_reference_state_field(
            public_fields,
            "execution.next_step_index",
            "emt.execution",
            "scheduler",
            "1",
        ),
        "workspace next step index",
    )
    public_next_time_s = _independent_reference_float(
        _independent_reference_state_field(
            public_fields,
            "execution.next_time",
            "emt.execution",
            "scheduler",
            "s",
        ),
        "workspace next time",
    )
    execution_mode = _independent_reference_state_field(
        public_fields,
        "workspace.execution_mode",
        "emt.workspace",
        "discrete",
        "1",
    )
    execution_mode == "hybrid" || throw(ArgumentError(
        "independent portable hybrid public state has the wrong execution owner",
    ))
    accepted_step == public_accepted_step &&
        _independent_reference_time_equal(accepted_time_s, public_accepted_time_s) &&
        next_step_index == public_next_step &&
        _independent_reference_time_equal(next_time_s, public_next_time_s) || throw(ArgumentError(
            "independent portable public and hybrid clocks disagree",
        ))
    _independent_reference_time_equal(accepted_time_s, accepted_step * timestep_s) || throw(ArgumentError(
        "independent portable accepted time disagrees with its fixed-step clock",
    ))
    next_step_index == min(accepted_step + 1, horizon_step_count + 1) ||
        throw(ArgumentError("independent portable next step cursor is inconsistent"))
    _independent_reference_time_equal(
        next_time_s,
        min(next_step_index, horizon_step_count) * timestep_s,
    ) ||
        throw(ArgumentError("independent portable next time cursor is inconsistent"))
    _independent_reference_time_equal(
        horizon_time_s,
        horizon_step_count * timestep_s,
    ) || throw(ArgumentError(
        "independent portable horizon disagrees with its fixed-step clock",
    ))
    snapshot.metadata.accepted_step == accepted_step &&
        _independent_reference_time_equal(
            Float64(snapshot.metadata.represented_time_s),
            accepted_time_s,
        ) ||
        throw(ArgumentError("independent portable metadata clock is inconsistent"))

    tick_s = _independent_reference_float(
        _independent_reference_state_field(
            hybrid_fields,
            "scheduler.tick",
            scheduler_owner,
            "checkpoint",
            "s",
        ),
        "scheduler tick",
    )
    origin_s = _independent_reference_float(
        _independent_reference_state_field(
            hybrid_fields,
            "scheduler.origin",
            scheduler_owner,
            "checkpoint",
            "s",
        ),
        "scheduler origin",
    )
    tick_s > 0.0 || throw(ArgumentError(
        "independent portable scheduler tick must be positive",
    ))
    task_records = _independent_reference_state_field(
        hybrid_fields,
        "scheduler.tasks",
        scheduler_owner,
        "scheduler",
        "1",
    )
    task_records isa AbstractVector && !isempty(task_records) || throw(ArgumentError(
        "independent portable hybrid reference requires exact action tasks",
    ))
    tasks = _independent_reference_action_task.(task_records)
    all(task -> task.tick_s == tick_s && task.period_ticks > 0, tasks) ||
        throw(ArgumentError("independent portable task clock is inconsistent"))
    length(unique(getfield.(tasks, :name))) == length(tasks) || throw(ArgumentError(
        "independent portable task inventory repeats a task identity",
    ))

    occurrence_records = _independent_reference_state_field(
        hybrid_fields,
        "scheduler.occurrences",
        scheduler_owner,
        "output",
        "1",
    )
    occurrence_records isa AbstractVector || throw(ArgumentError(
        "independent portable task occurrence state is not a sequence",
    ))
    task_occurrences = _independent_reference_task_occurrence.(occurrence_records)
    occurrences_by_task = Dict(
        task.name => filter(occurrence -> occurrence.name == task.name, task_occurrences)
        for task in tasks
    )
    for task in tasks
        occurrences = occurrences_by_task[task.name]
        length(occurrences) == task.execution_count || throw(ArgumentError(
            "independent portable task execution count disagrees with occurrences",
        ))
        for (index, occurrence) in pairs(occurrences)
            occurrence.execution_index == index || throw(ArgumentError(
                "independent portable task execution indices are not contiguous",
            ))
            occurrence.priority == task.priority || throw(ArgumentError(
                "independent portable task priority changed",
            ))
            _independent_reference_time_equal(
                occurrence.time_s,
                origin_s + occurrence.tick * tick_s,
            ) ||
                throw(ArgumentError("independent portable task occurrence time is inexact"))
            index == 1 || occurrence.tick == occurrences[index - 1].tick + task.period_ticks ||
                throw(ArgumentError("independent portable task calendar is discontinuous"))
        end
        if isempty(occurrences)
            task.last_execution_tick == -1 || throw(ArgumentError(
                "independent portable unexecuted task has a last tick",
            ))
        else
            task.last_execution_tick == last(occurrences).tick || throw(ArgumentError(
                "independent portable task last tick disagrees with occurrences",
            ))
            task.next_tick == task.last_execution_tick + task.period_ticks ||
                throw(ArgumentError("independent portable task next tick is discontinuous"))
        end
    end

    future_task_occurrences = IndependentPortableHybridTaskOccurrence[]
    for task in tasks
        tick = task.next_tick
        execution_index = task.execution_count
        while origin_s + tick * tick_s <= horizon_time_s + eps(horizon_time_s)
            execution_index += 1
            push!(future_task_occurrences, IndependentPortableHybridTaskOccurrence(
                task.name,
                origin_s + tick * tick_s,
                tick,
                task.priority,
                execution_index,
            ))
            tick += task.period_ticks
        end
    end
    sort!(future_task_occurrences; by = occurrence -> (
        occurrence.tick,
        occurrence.priority,
        occurrence.name,
    ))

    surface_records = _independent_reference_state_field(
        hybrid_fields,
        "hybrid.surfaces",
        hybrid_owner,
        "checkpoint",
        "1",
    )
    surface_records isa AbstractVector || throw(ArgumentError(
        "independent portable hybrid surface state is not a sequence",
    ))
    surfaces = _independent_reference_surface.(surface_records)
    surface_names = getfield.(surfaces, :name)
    length(unique(surface_names)) == length(surface_names) || throw(ArgumentError(
        "independent portable hybrid surfaces repeat an identity",
    ))
    fired_values = _independent_reference_state_field(
        hybrid_fields,
        "hybrid.surface_fired",
        hybrid_owner,
        "discrete",
        "1",
    )
    fired_values isa AbstractVector && all(value -> value isa Bool, fired_values) ||
        throw(ArgumentError("independent portable fired-surface state is not Boolean"))
    surface_fired = Bool[value for value in fired_values]
    length(surface_fired) == length(surfaces) || throw(ArgumentError(
        "independent portable fired-surface state changed shape",
    ))
    event_records = _independent_reference_state_field(
        hybrid_fields,
        "hybrid.occurrences",
        hybrid_owner,
        "output",
        "1",
    )
    event_records isa AbstractVector || throw(ArgumentError(
        "independent portable event occurrence state is not a sequence",
    ))
    event_occurrences = _independent_reference_event_occurrence.(event_records)
    for occurrence in event_occurrences
        surface_index = findfirst(==(occurrence.name), surface_names)
        surface_index === nothing && throw(ArgumentError(
            "independent portable event occurrence has no surface owner",
        ))
        occurrence.time_s <= accepted_time_s || throw(ArgumentError(
            "independent portable event occurrence lies after the accepted endpoint",
        ))
        surfaces[surface_index].repeatable || surface_fired[surface_index] ||
            throw(ArgumentError("independent portable nonrepeatable event is not fired"))
    end

    values = (
        public_inventory_signature_sha256 = public_signature,
        hybrid_inventory_signature_sha256 = hybrid_signature,
        accepted_step,
        accepted_time_s,
        next_step_index,
        next_time_s,
        horizon_step_count,
        horizon_time_s,
        task_program_signature_sha256 = task_signature,
        event_program_signature_sha256 = event_signature,
        task_occurrences,
        future_task_occurrences,
        event_occurrences,
        surface_names,
        surface_fired,
    )
    return IndependentPortableHybridReference(
        values.public_inventory_signature_sha256,
        values.hybrid_inventory_signature_sha256,
        values.accepted_step,
        values.accepted_time_s,
        values.next_step_index,
        values.next_time_s,
        values.horizon_step_count,
        values.horizon_time_s,
        values.task_program_signature_sha256,
        values.event_program_signature_sha256,
        values.task_occurrences,
        values.future_task_occurrences,
        values.event_occurrences,
        values.surface_names,
        values.surface_fired,
        _independent_reference_signature(values),
    )
end
