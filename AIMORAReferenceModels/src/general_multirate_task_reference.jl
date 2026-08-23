const _INDEPENDENT_TASK_STAGE_ORDER = (:read, :compute, :enqueue, :write, :hold)

function _independent_rational_time(value::Integer)
    return Rational{BigInt}(BigInt(value), BigInt(1))
end

function _independent_rational_time(value::Rational)
    return Rational{BigInt}(BigInt(numerator(value)), BigInt(denominator(value)))
end

_independent_rational_time(::AbstractFloat) = throw(ArgumentError(
    "independent task calendar values must be exact integers or rationals",
))

function _independent_task_names(values, label::String)
    names = sort!(String[String(value) for value in values])
    any(name -> isempty(strip(name)) || occursin('\0', name), names) &&
        throw(ArgumentError("independent task $label contains an invalid identity"))
    length(names) == length(unique(names)) || throw(ArgumentError(
        "independent task $label contains a duplicate identity",
    ))
    return Tuple(names)
end

"""One callback-free task row for the independent exact calendar and staged-hold formulation."""
struct IndependentTaskCalendarSpec
    name::String
    family_rank::Int
    epoch::Rational{BigInt}
    period::Rational{BigInt}
    phase::Rational{BigInt}
    computational_delay::Rational{BigInt}
    priority::Int
    read_resources::Tuple
    write_resources::Tuple
    predecessors::Tuple

    function IndependentTaskCalendarSpec(
        name::AbstractString,
        family_rank::Integer,
        epoch,
        period,
        phase,
        computational_delay;
        priority::Integer = 0,
        read_resources = String[],
        write_resources = String[],
        predecessors = String[],
    )
        identity = String(name)
        isempty(strip(identity)) && throw(ArgumentError(
            "independent task identity must not be empty",
        ))
        rank = Int(family_rank)
        1 <= rank <= 8 || throw(ArgumentError(
            "independent task family rank must identify one of eight families",
        ))
        exact_epoch = _independent_rational_time(epoch)
        exact_period = _independent_rational_time(period)
        exact_phase = _independent_rational_time(phase)
        exact_delay = _independent_rational_time(computational_delay)
        1 // big(1_000_000_000) <= exact_period <= 1_000 // big(1) ||
            throw(ArgumentError("independent task period is outside 1 ns through 1,000 s"))
        0 <= exact_phase < exact_period || throw(ArgumentError(
            "independent task phase must be in [0, period)",
        ))
        0 <= exact_delay <= 100 * exact_period || throw(ArgumentError(
            "independent task delay must be from zero through 100 periods",
        ))
        dependencies = _independent_task_names(predecessors, "predecessors")
        identity in dependencies && throw(ArgumentError(
            "independent task cannot depend on itself",
        ))
        return new(
            identity,
            rank,
            exact_epoch,
            exact_period,
            exact_phase,
            exact_delay,
            Int(priority),
            _independent_task_names(read_resources, "read resources"),
            _independent_task_names(write_resources, "write resources"),
            dependencies,
        )
    end
end

"""One independently enumerated task stage at an exact rational instant."""
struct IndependentTaskOccurrence
    task::String
    family_rank::Int
    instant::Rational{BigInt}
    stage::Symbol
    priority::Int
    activation_index::Int
    sample_index::Int
    release_index::Int
    execution_index::Int
end

function Base.:(==)(left::IndependentTaskOccurrence, right::IndependentTaskOccurrence)
    return left.task == right.task &&
        left.family_rank == right.family_rank &&
        left.instant == right.instant &&
        left.stage == right.stage &&
        left.priority == right.priority &&
        left.activation_index == right.activation_index &&
        left.sample_index == right.sample_index &&
        left.release_index == right.release_index &&
        left.execution_index == right.execution_index
end

Base.isequal(left::IndependentTaskOccurrence, right::IndependentTaskOccurrence) =
    isequal(
        (
            left.task,
            left.family_rank,
            left.instant,
            left.stage,
            left.priority,
            left.activation_index,
            left.sample_index,
            left.release_index,
            left.execution_index,
        ),
        (
            right.task,
            right.family_rank,
            right.instant,
            right.stage,
            right.priority,
            right.activation_index,
            right.sample_index,
            right.release_index,
            right.execution_index,
        ),
    )

Base.hash(occurrence::IndependentTaskOccurrence, seed::UInt) = hash(
    (
        occurrence.task,
        occurrence.family_rank,
        occurrence.instant,
        occurrence.stage,
        occurrence.priority,
        occurrence.activation_index,
        occurrence.sample_index,
        occurrence.release_index,
        occurrence.execution_index,
    ),
    seed,
)

"""Complete independent staged-calendar result, including held values and a deterministic digest."""
struct IndependentTaskReferenceResult
    start::Rational{BigInt}
    stop::Rational{BigInt}
    quantum::Rational{BigInt}
    execution_order::Vector{String}
    occurrences::Vector{IndependentTaskOccurrence}
    activation_counts::Vector{Pair{String,Int}}
    release_counts::Vector{Pair{String,Int}}
    maximum_pending_depths::Vector{Pair{String,Int}}
    held_outputs::Vector{Pair{String,Rational{BigInt}}}
    deterministic_signature_sha256::String
end

function _independent_task_order(specifications::Vector{IndependentTaskCalendarSpec})
    names = getfield.(specifications, :name)
    length(names) == length(unique(names)) || throw(ArgumentError(
        "independent task plan repeats an identity",
    ))
    indices = Dict(name => index for (index, name) in pairs(names))
    successors = [Int[] for _ in specifications]
    indegrees = zeros(Int, length(specifications))
    edge_count = 0
    for (target, specification) in pairs(specifications)
        for predecessor in specification.predecessors
            source = get(indices, predecessor, 0)
            source > 0 || throw(ArgumentError(
                "independent task predecessor is absent from the plan",
            ))
            push!(successors[source], target)
            indegrees[target] += 1
            edge_count += 1
        end
    end
    edge_count <= 4_096 || throw(ArgumentError(
        "independent task plan exceeds 4,096 predecessor edges",
    ))
    order = Int[]
    selected = falses(length(specifications))
    while length(order) < length(specifications)
        ready = Int[
            index for index in eachindex(specifications)
            if !selected[index] && indegrees[index] == 0
        ]
        isempty(ready) && throw(ArgumentError(
            "independent task predecessor graph contains a cycle",
        ))
        sort!(ready; by = index -> begin
            specification = specifications[index]
            (
                specification.priority,
                specification.family_rank,
                specification.name,
                index,
            )
        end)
        next_index = first(ready)
        selected[next_index] = true
        push!(order, next_index)
        for target in successors[next_index]
            indegrees[target] -= 1
        end
    end
    reachable = falses(length(specifications), length(specifications))
    for source in reverse(order)
        for target in successors[source]
            reachable[source, target] = true
            for downstream in eachindex(specifications)
                reachable[target, downstream] &&
                    (reachable[source, downstream] = true)
            end
        end
    end
    return order, reachable
end

function _independent_task_activations(
    specification::IndependentTaskCalendarSpec,
    start::Rational{BigInt},
    stop::Rational{BigInt},
)
    first_instant = specification.epoch + specification.phase
    if first_instant < start
        first_instant += cld(start - first_instant, specification.period) *
            specification.period
    end
    first_instant > stop && return Rational{BigInt}[]
    count = floor(BigInt, (stop - first_instant) / specification.period) + 1
    count <= 1_000_000 || throw(ArgumentError(
        "independent task activation count exceeds 1,000,000",
    ))
    return Rational{BigInt}[
        first_instant + index * specification.period for index in BigInt(0):(count - 1)
    ]
end

function _independent_task_conflict(
    left::IndependentTaskCalendarSpec,
    right::IndependentTaskCalendarSpec,
)
    left_reads = Set(left.read_resources)
    left_writes = Set(left.write_resources)
    right_reads = Set(right.read_resources)
    right_writes = Set(right.write_resources)
    return !isempty(intersect(left_writes, union(right_reads, right_writes))) ||
        !isempty(intersect(right_writes, left_reads))
end

function _independent_task_quantum(
    specifications::Vector{IndependentTaskCalendarSpec},
    start::Rational{BigInt},
    stop::Rational{BigInt},
)
    values = Rational{BigInt}[stop - start]
    for specification in specifications
        append!(values, (
            specification.period,
            specification.phase,
            specification.computational_delay,
            specification.epoch - start,
        ))
    end
    common_denominator = foldl(lcm, Base.denominator.(values); init = BigInt(1))
    integers = BigInt[
        numerator(value) * div(common_denominator, Base.denominator(value))
        for value in values
    ]
    divisor = foldl(gcd, abs.(integers); init = BigInt(0))
    iszero(divisor) && throw(ArgumentError(
        "independent task calendar has no positive quantum",
    ))
    return divisor // common_denominator
end

function _independent_task_signature(result_without_signature)
    io = IOBuffer()
    println(io, "aimora-independent-general-task-reference-v1")
    for value in result_without_signature
        show(io, MIME("text/plain"), value)
        write(io, UInt8('\n'))
    end
    return bytes2hex(sha256(take!(io)))
end

"""
    independent_multirate_task_reference(specifications; start, stop, initial_outputs, sample_value)

Enumerate activations and delayed releases directly with exact `Rational{BigInt}`
arithmetic, independently order the declared DAG, and apply the staged
`read -> compute -> enqueue -> write -> hold` recurrence. `sample_value` is a
pure synthetic reference callback receiving `(specification, activation_index,
copy_of_current_holds)` and must return an exact integer or rational value.
"""
function independent_multirate_task_reference(
    declarations::AbstractVector{IndependentTaskCalendarSpec};
    start,
    stop,
    initial_outputs = Pair{String,Rational{BigInt}}[],
    sample_value = (specification, activation_index, _held) ->
        activation_index // big(1),
)
    specifications = collect(declarations)
    isempty(specifications) && throw(ArgumentError(
        "independent task reference requires at least one declaration",
    ))
    length(specifications) <= 1_024 || throw(ArgumentError(
        "independent task reference exceeds 1,024 declarations",
    ))
    exact_start = _independent_rational_time(start)
    exact_stop = _independent_rational_time(stop)
    exact_start <= exact_stop || throw(ArgumentError(
        "independent task stop must not precede its start",
    ))
    order, reachable = _independent_task_order(specifications)
    activations = [
        _independent_task_activations(specification, exact_start, exact_stop)
        for specification in specifications
    ]
    activation_sets = Set.(activations)
    for left_index in eachindex(specifications)
        for right_index in (left_index + 1):length(specifications)
            _independent_task_conflict(
                specifications[left_index],
                specifications[right_index],
            ) || continue
            isempty(intersect(
                activation_sets[left_index],
                activation_sets[right_index],
            )) && continue
            (reachable[left_index, right_index] || reachable[right_index, left_index]) ||
                throw(ArgumentError(
                    "independent same-instant conflicting tasks require a predecessor path",
                ))
        end
    end
    held = Dict{String,Rational{BigInt}}(
        specification.name => 0 // big(1) for specification in specifications
    )
    for (name, value) in initial_outputs
        haskey(held, name) || throw(ArgumentError(
            "independent initial output names an unknown task",
        ))
        held[name] = _independent_rational_time(value)
    end
    pending = [
        Tuple{Rational{BigInt},Int,Rational{BigInt}}[] for _ in specifications
    ]
    activation_counts = zeros(Int, length(specifications))
    release_counts = zeros(Int, length(specifications))
    maximum_pending_depths = zeros(Int, length(specifications))
    all_instants = Set{Rational{BigInt}}()
    foreach(set -> union!(all_instants, set), activation_sets)
    for (index, specification) in pairs(specifications)
        for activation in activations[index]
            release = activation + specification.computational_delay
            release <= exact_stop && push!(all_instants, release)
        end
    end
    occurrences = IndependentTaskOccurrence[]
    execution_index = 0
    for instant in sort!(collect(all_instants))
        for task_index in order
            specification = specifications[task_index]
            activated = instant in activation_sets[task_index]
            release_due = any(first(value) == instant for value in pending[task_index])
            (activated || release_due) || continue
            if activated
                activation_counts[task_index] += 1
                activation_index = activation_counts[task_index]
                for stage in (:read, :compute)
                    execution_index += 1
                    push!(occurrences, IndependentTaskOccurrence(
                        specification.name,
                        specification.family_rank,
                        instant,
                        stage,
                        specification.priority,
                        activation_index,
                        activation_index,
                        release_counts[task_index],
                        execution_index,
                    ))
                end
                value = _independent_rational_time(sample_value(
                    specification,
                    activation_index,
                    copy(held),
                ))
                push!(
                    pending[task_index],
                    (
                        instant + specification.computational_delay,
                        activation_index,
                        value,
                    ),
                )
                sort!(pending[task_index]; by = item -> (item[1], item[2]))
                maximum_pending_depths[task_index] = max(
                    maximum_pending_depths[task_index],
                    length(pending[task_index]),
                )
                execution_index += 1
                push!(occurrences, IndependentTaskOccurrence(
                    specification.name,
                    specification.family_rank,
                    instant,
                    :enqueue,
                    specification.priority,
                    activation_index,
                    activation_index,
                    release_counts[task_index],
                    execution_index,
                ))
            end
            while !isempty(pending[task_index]) &&
                  pending[task_index][1][1] == instant
                _, sample_index, value = popfirst!(pending[task_index])
                release_counts[task_index] += 1
                held[specification.name] = value
                execution_index += 1
                push!(occurrences, IndependentTaskOccurrence(
                    specification.name,
                    specification.family_rank,
                    instant,
                    :write,
                    specification.priority,
                    activation_counts[task_index],
                    sample_index,
                    release_counts[task_index],
                    execution_index,
                ))
            end
            execution_index += 1
            push!(occurrences, IndependentTaskOccurrence(
                specification.name,
                specification.family_rank,
                instant,
                :hold,
                specification.priority,
                activation_counts[task_index],
                activation_counts[task_index],
                release_counts[task_index],
                execution_index,
            ))
        end
    end
    quantum = _independent_task_quantum(
        specifications,
        exact_start,
        exact_stop,
    )
    order_names = String[specifications[index].name for index in order]
    activation_pairs = Pair{String,Int}[
        specifications[index].name => activation_counts[index]
        for index in eachindex(specifications)
    ]
    release_pairs = Pair{String,Int}[
        specifications[index].name => release_counts[index]
        for index in eachindex(specifications)
    ]
    pending_pairs = Pair{String,Int}[
        specifications[index].name => maximum_pending_depths[index]
        for index in eachindex(specifications)
    ]
    held_pairs = Pair{String,Rational{BigInt}}[
        name => held[name] for name in sort!(collect(keys(held)))
    ]
    signature = _independent_task_signature((
        exact_start,
        exact_stop,
        quantum,
        order_names,
        occurrences,
        activation_pairs,
        release_pairs,
        pending_pairs,
        held_pairs,
    ))
    return IndependentTaskReferenceResult(
        exact_start,
        exact_stop,
        quantum,
        order_names,
        occurrences,
        activation_pairs,
        release_pairs,
        pending_pairs,
        held_pairs,
        signature,
    )
end
