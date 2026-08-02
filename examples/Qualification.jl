module AIMORAExampleQualification

using TOML

export ExampleTarget,
       example_targets,
       run_examples,
       select_changed_targets,
       select_targets

struct ExampleTarget
    id::String
    directory::String
    entrypoint::String
end

function example_targets(root::AbstractString)
    catalog = TOML.parsefile(joinpath(root, "examples", "catalog.toml"))
    get(catalog, "schema", nothing) == "aimora-examples-v2" ||
        error("unsupported AIMORA example catalog schema")
    targets = ExampleTarget[]
    for row in catalog["case"]
        entrypoint = replace(String(row["entrypoint"]), '\\' => '/')
        directory = dirname(entrypoint)
        isfile(joinpath(root, entrypoint)) || error("missing example entrypoint: $(entrypoint)")
        isfile(joinpath(root, directory, "Makefile")) ||
            error("missing example Makefile: $(directory)")
        push!(targets, ExampleTarget(String(row["id"]), directory, entrypoint))
    end
    length(unique(target.id for target in targets)) == length(targets) ||
        error("example target ids are not unique")
    length(unique(target.directory for target in targets)) == length(targets) ||
        error("example target directories are not unique")
    return sort!(targets; by = target -> target.id)
end

function select_targets(targets::Vector{ExampleTarget}, ids::Vector{String})
    by_id = Dict(target.id => target for target in targets)
    unknown = sort!(filter(id -> !haskey(by_id, id), unique(ids)))
    isempty(unknown) || error("unknown AIMORA example ids: $(join(unknown, ", "))")
    return sort!([by_id[id] for id in unique(ids)]; by = target -> target.id)
end

function select_changed_targets(targets::Vector{ExampleTarget}, paths::Vector{String})
    selected = ExampleTarget[]
    for target in targets
        prefix = target.directory * "/"
        any(paths) do raw_path
            path = replace(raw_path, '\\' => '/')
            path == target.directory || startswith(path, prefix)
        end && push!(selected, target)
    end
    return sort!(unique(selected); by = target -> target.id)
end

function _append_timing(path::AbstractString, target::ExampleTarget, elapsed_seconds::Real, status::String)
    isempty(path) && return
    mkpath(dirname(path))
    new_file = !isfile(path)
    open(path, "a") do io
        new_file && println(io, "example_id\tdirectory\telapsed_s\tstatus")
        println(
            io,
            join(
                (
                    target.id,
                    target.directory,
                    round(Float64(elapsed_seconds); digits = 3),
                    status,
                ),
                '\t',
            ),
        )
    end
end

function run_examples(
    root::AbstractString,
    targets::Vector{ExampleTarget};
    plan_only::Bool = false,
    timing_path::AbstractString = "",
)
    isempty(targets) && begin
        println("No runnable example directory was affected")
        return true
    end
    println("Selected AIMORA examples ($(length(targets))): ", join((target.id for target in targets), ", "))
    plan_only && return true
    julia = get(ENV, "JULIA", join(Base.julia_cmd().exec, " "))
    for target in targets
        command = Cmd([
            "make",
            "--no-print-directory",
            "-C",
            joinpath(root, target.directory),
            "JULIA=$(julia)",
            "run",
        ])
        println("[run] $(target.id) (no timeout; one attempt)")
        started = time_ns()
        status = "passed"
        try
            run(command)
        catch
            status = "failed"
            rethrow()
        finally
            elapsed = (time_ns() - started) / 1.0e9
            _append_timing(timing_path, target, elapsed, status)
        end
        elapsed = (time_ns() - started) / 1.0e9
        println("[ok] $(target.id) $(round(elapsed; digits = 1))s")
    end
    return true
end

end
