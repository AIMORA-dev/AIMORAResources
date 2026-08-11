#!/usr/bin/env julia

const ROOT = normpath(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "Qualification.jl"))
using .AIMORAExampleQualification

function usage(io::IO = stderr)
    println(io, "Usage:")
    println(io, "  julia examples/run_examples.jl --id ID [--id ID ...] [--plan]")
    println(io, "  julia examples/run_examples.jl --changed PATH [PATH ...] [--plan]")
    println(io, "  julia examples/run_examples.jl --all --release [--force] [--plan]")
end

function main(arguments::Vector{String})
    isempty(arguments) && (usage(); return 2)
    ids = String[]
    changed = String[]
    run_all = false
    plan_only = false
    release = false
    force = false
    index = 1
    while index <= length(arguments)
        argument = arguments[index]
        if argument == "--id"
            index += 1
            index <= length(arguments) || (usage(); return 2)
            push!(ids, arguments[index])
        elseif argument == "--changed"
            index += 1
            while index <= length(arguments) && !startswith(arguments[index], "--")
                push!(changed, arguments[index])
                index += 1
            end
            index -= 1
        elseif argument == "--all"
            run_all = true
        elseif argument == "--plan"
            plan_only = true
        elseif argument == "--release"
            release = true
        elseif argument == "--force"
            force = true
        else
            usage()
            return 2
        end
        index += 1
    end
    selection_count = !isempty(ids) + !isempty(changed) + run_all
    selection_count == 1 || (usage(); return 2)
    targets = example_targets(ROOT)
    selected = run_all ? targets :
        !isempty(ids) ? select_targets(targets, ids) : select_changed_targets(targets, changed)
    run_all && (release = true)
    worker_count = release ? parse(Int, get(ENV, "AIMORA_EXAMPLE_WORKERS", "5")) : 1
    timing_path = get(ENV, "AIMORA_EXAMPLE_TIMINGS_PATH", "")
    run_examples(ROOT, selected; plan_only, timing_path, release, force, worker_count)
    return 0
end

exit(main(ARGS))
