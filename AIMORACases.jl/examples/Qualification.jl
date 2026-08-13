module AIMORAExampleQualification

using Distributed
using SHA
using TOML

export ExampleTarget,
       ExampleRunResult,
       example_targets,
       example_signature,
       receipt_is_valid,
       run_examples,
       select_changed_targets,
       select_targets

struct ExampleTarget
    id::String
    directory::String
    entrypoint::String
end

struct ExampleRunResult
    id::String
    elapsed_seconds::Float64
    status::String
    error_message::String
end

struct ExampleSignatureContext
    common_signature::String
end

const RECEIPT_SCHEMA = "aimora.example_receipt.v1"

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

function _nul_paths(command::Cmd)
    return filter(!isempty, split(read(command, String), '\0'))
end

function _git_content_signature(repository::AbstractString)
    ispath(joinpath(repository, ".git")) || return "unavailable"
    paths = sort!(_nul_paths(`git -C $repository ls-files --cached --others --exclude-standard -z`))
    modes = Dict{String,String}()
    for record in _nul_paths(`git -C $repository ls-files --stage -z`)
        fields = split(record, '\t'; limit = 2)
        length(fields) == 2 || continue
        metadata = split(first(fields))
        isempty(metadata) || (modes[last(fields)] = first(metadata))
    end
    io = IOBuffer()
    for relative_path in paths
        mode = get(modes, relative_path, "untracked")
        print(io, mode, '\0', relative_path, '\0')
        full_path = joinpath(repository, relative_path)
        if mode == "160000"
            print(io, "gitlink-owned-separately")
        elseif islink(full_path)
            print(io, "symlink\0", readlink(full_path))
        elseif isfile(full_path)
            print(io, bytes2hex(open(sha256, full_path)))
        else
            print(io, "missing")
        end
        print(io, '\0')
    end
    return bytes2hex(sha256(take!(io)))
end

function _tree_signature(root::AbstractString, relative_paths::Vector{String})
    entries = Pair{String,String}[]
    for relative_path in relative_paths
        full_path = joinpath(root, relative_path)
        if isfile(full_path)
            push!(entries, relative_path => bytes2hex(open(sha256, full_path)))
        elseif isdir(full_path)
            for (directory, directories, files) in walkdir(full_path)
                sort!(directories)
                for filename in sort!(files)
                    path = joinpath(directory, filename)
                    relative = replace(relpath(path, root), '\\' => '/')
                    push!(entries, relative => bytes2hex(open(sha256, path)))
                end
            end
        else
            push!(entries, relative_path => "missing")
        end
    end
    sort!(entries; by = first)
    return bytes2hex(sha256(join(("$(first(entry))\0$(last(entry))" for entry in entries), '\0')))
end

function _example_signature_context(root::AbstractString)
    workspace = normpath(joinpath(root, ".."))
    engine = abspath(get(ENV, "AIMORA_ENGINE_PATH", joinpath(workspace, "AIMORA.jl")))
    solver = abspath(get(ENV, "AIMORA_SOLVER_PATH", joinpath(dirname(engine), "AIMORASolvers.jl")))
    shared_paths = [
        "Project.toml",
        "Manifest.toml",
        "src",
        "examples/catalog.toml",
        "examples/load_aimora.jl",
        "examples/support",
        "examples/Qualification.jl",
        "examples/run_examples.jl",
    ]
    lines = String[
        "schema=$(RECEIPT_SCHEMA)",
        "julia=$(VERSION)",
        "kernel=$(Sys.KERNEL)",
        "architecture=$(Sys.ARCH)",
        "word_size=$(Sys.WORD_SIZE)",
        "julia_cpu_target=$(get(ENV, "JULIA_CPU_TARGET", ""))",
        "threads=$(get(ENV, "JULIA_NUM_THREADS", "1"))",
        "blas=$(get(ENV, "OPENBLAS_NUM_THREADS", "1"))",
        "omp=$(get(ENV, "OMP_NUM_THREADS", "1"))",
        "lang=$(get(ENV, "LANG", ""))",
        "lc_all=$(get(ENV, "LC_ALL", ""))",
        "timezone=$(get(ENV, "TZ", ""))",
        "cases=$(_tree_signature(root, shared_paths))",
        "engine=$(_git_content_signature(engine))",
        "solver=$(_git_content_signature(solver))",
    ]
    return ExampleSignatureContext(bytes2hex(sha256(join(lines, '\n') * "\n")))
end

function _example_signature(
    context::ExampleSignatureContext,
    root::AbstractString,
    target::ExampleTarget,
)
    lines = (
        "schema=$(RECEIPT_SCHEMA)",
        "common=$(context.common_signature)",
        "example=$(target.id)",
        "target=$(_tree_signature(root, [target.directory]))",
    )
    return bytes2hex(sha256(join(lines, '\n') * "\n"))
end

function example_signature(root::AbstractString, target::ExampleTarget)
    return _example_signature(_example_signature_context(root), root, target)
end

function _receipt_path(root::AbstractString, target::ExampleTarget, signature::AbstractString)
    return joinpath(root, ".qualification", "receipts", target.id, "$(signature).toml")
end

function receipt_is_valid(
    path::AbstractString,
    expected_signature::AbstractString,
    expected_example_id::Union{Nothing,AbstractString} = nothing,
)
    isfile(path) || return false
    try
        outer = TOML.parsefile(path)
        payload = String(outer["payload"])
        bytes2hex(sha256(payload)) == String(outer["payload_sha256"]) || return false
        parsed = TOML.parse(payload)
        identity_matches = expected_example_id === nothing ||
            get(parsed, "example_id", nothing) == expected_example_id
        return identity_matches &&
               get(parsed, "schema", nothing) == RECEIPT_SCHEMA &&
               get(parsed, "status", nothing) == "passed" &&
               get(parsed, "signature", nothing) == expected_signature
    catch
        return false
    end
end

function _write_receipt(
    root::AbstractString,
    target::ExampleTarget,
    signature::AbstractString,
    elapsed_seconds::Real,
)
    payload_buffer = IOBuffer()
    TOML.print(
        payload_buffer,
        Dict{String,Any}(
            "schema" => RECEIPT_SCHEMA,
            "status" => "passed",
            "signature" => String(signature),
            "example_id" => target.id,
            "elapsed_seconds" => Float64(elapsed_seconds),
        );
        sorted = true,
    )
    payload = String(take!(payload_buffer))
    path = _receipt_path(root, target, signature)
    mkpath(dirname(path))
    open(path, "w") do io
        TOML.print(
            io,
            Dict("payload" => payload, "payload_sha256" => bytes2hex(sha256(payload)));
            sorted = true,
        )
    end
    return path
end

function _artifact_inventory(directory::AbstractString)
    isdir(directory) || return Dict{String,String}()
    inventory = Dict{String,String}()
    for (root, directories, files) in walkdir(directory)
        sort!(directories)
        for filename in sort!(files)
            path = joinpath(root, filename)
            inventory[replace(relpath(path, directory), '\\' => '/')] =
                bytes2hex(open(sha256, path))
        end
    end
    return inventory
end

function _normalized_output_paths(
    path::AbstractString,
    expected_directory::AbstractString,
    generated_directory::AbstractString,
)
    text = read(path, String)
    return replace(
        text,
        abspath(expected_directory) => "outputs",
        abspath(generated_directory) => "outputs",
    )
end

function _assert_realtime_summary(
    expected_path::AbstractString,
    generated_path::AbstractString,
)
    expected = read(expected_path, String)
    generated = read(generated_path, String)
    timing_pattern = r"(?m)^  \"(?:mean|max)_step_s\": [^,\n]+,?\n"
    replace(expected, timing_pattern => "") == replace(generated, timing_pattern => "") ||
        error("realtime summary changed outside measured timing fields")
    function timing_value(text::String, name::String)
        matched = match(Regex("\\\"$(name)\\\"\\s*:\\s*([0-9.eE+-]+)"), text)
        matched === nothing && error("realtime summary is missing $name")
        value = tryparse(Float64, only(matched.captures))
        value === nothing && error("realtime summary has invalid $name")
        return value
    end
    mean_step_s = timing_value(generated, "mean_step_s")
    maximum_step_s = timing_value(generated, "max_step_s")
    dt_s = timing_value(generated, "dt_s")
    0.0 < mean_step_s <= maximum_step_s <= dt_s || error(
        "realtime summary timing fields are outside the declared fixed-step budget",
    )
    return true
end

function _read_little_endian_integer(io::IO, ::Type{T}) where {T<:Unsigned}
    value = zero(T)
    for shift in 0:8:(8 * sizeof(T) - 8)
        eof(io) && error("checkpoint envelope is truncated")
        value |= T(read(io, UInt8)) << shift
    end
    return value
end

function _checkpoint_envelope(path::AbstractString)
    magic = collect(codeunits("AIMORA-EMT-CHECKPOINT"))
    return open(path, "r") do io
        read(io, length(magic)) == magic || error("checkpoint magic is invalid")
        schema = _read_little_endian_integer(io, UInt32)
        payload_length = _read_little_endian_integer(io, UInt64)
        digest = read(io, 32)
        length(digest) == 32 || error("checkpoint digest is truncated")
        payload_length <= UInt64(typemax(Int)) || error("checkpoint payload is too large")
        payload = read(io, Int(payload_length))
        length(payload) == Int(payload_length) || error("checkpoint payload is truncated")
        eof(io) || error("checkpoint has trailing bytes")
        sha256(payload) == digest || error("checkpoint payload digest is invalid")
        return (schema = schema, payload_length = payload_length)
    end
end

function _assert_checkpoint_envelopes(
    expected_path::AbstractString,
    generated_path::AbstractString,
)
    expected = _checkpoint_envelope(expected_path)
    generated = _checkpoint_envelope(generated_path)
    expected == generated || error(
        "checkpoint schema or payload length changed; semantic restart evidence must be reviewed",
    )
    return true
end

function _assert_known_variable_artifact(
    target::ExampleTarget,
    relative_path::AbstractString,
    expected_path::AbstractString,
    generated_path::AbstractString,
    expected_directory::AbstractString,
    generated_directory::AbstractString,
)
    if target.id == "emt_parsed_deck_trace" && endswith(relative_path, "_manifest.json")
        _normalized_output_paths(
            expected_path,
            expected_directory,
            generated_directory,
        ) == _normalized_output_paths(
            generated_path,
            expected_directory,
            generated_directory,
        ) || error("portable report manifest content changed")
        return true
    elseif target.id == "emt_realtime_cpu" && relative_path == "realtime_summary.json"
        return _assert_realtime_summary(expected_path, generated_path)
    elseif target.id == "emt_checkpoint_restart" && endswith(relative_path, ".aimora")
        return _assert_checkpoint_envelopes(expected_path, generated_path)
    end
    return false
end

function _assert_exact_artifacts(
    root::AbstractString,
    target::ExampleTarget,
    generated_directory::AbstractString,
)
    expected_directory = joinpath(root, target.directory, "outputs")
    expected = _artifact_inventory(expected_directory)
    generated = _artifact_inventory(generated_directory)
    isempty(expected) && error("example $(target.id) has no committed output artifacts")
    missing = sort!(collect(setdiff(keys(expected), keys(generated))))
    extra = sort!(collect(setdiff(keys(generated), keys(expected))))
    changed = String[]
    variable_artifact_failures = String[]
    for path in sort!(collect(intersect(keys(expected), keys(generated))))
        expected[path] == generated[path] && continue
        expected_path = joinpath(expected_directory, path)
        generated_path = joinpath(generated_directory, path)
        accepted = try
            _assert_known_variable_artifact(
                target,
                path,
                expected_path,
                generated_path,
                expected_directory,
                generated_directory,
            )
        catch exception
            push!(variable_artifact_failures, "$path: $(sprint(showerror, exception))")
            false
        end
        accepted || push!(changed, path)
    end
    isempty(missing) && isempty(extra) && isempty(changed) &&
        isempty(variable_artifact_failures) || begin
        error(
            "example $(target.id) artifacts are not deterministic; " *
            "missing=$(join(missing, ',')); extra=$(join(extra, ',')); " *
            "changed=$(join(changed, ',')); " *
            "variable_failures=$(join(variable_artifact_failures, '|'))",
        )
    end
    return true
end

function _retain_failed_artifacts(
    root::AbstractString,
    target::ExampleTarget,
    signature::AbstractString,
    generated_directory::AbstractString,
)
    destination = joinpath(
        root,
        ".qualification",
        "failures",
        target.id,
        signature,
        string(time_ns()),
    )
    mkpath(dirname(destination))
    cp(generated_directory, destination; force = false)
    return destination
end

function _execute_example(
    root::AbstractString,
    target::ExampleTarget,
    output_directory::AbstractString,
)
    started = time_ns()
    status = "passed"
    error_message = ""
    original_arguments = copy(ARGS)
    original_load_path = copy(LOAD_PATH)
    original_directory = pwd()
    original_environment = Dict{String,String}(ENV)
    try
        mkpath(output_directory)
        empty!(ARGS)
        push!(ARGS, abspath(output_directory))
        module_name = Symbol("AIMORAExample_", replace(target.id, r"[^A-Za-z0-9_]" => "_"), "_", time_ns())
        example_module = Module(module_name, true, true)
        Core.eval(
            example_module,
            :(include(path::AbstractString) = Base.include($(QuoteNode(example_module)), path)),
        )
        Base.include(example_module, joinpath(root, target.entrypoint))
    catch exception
        status = "failed"
        error_message = sprint(showerror, exception, catch_backtrace())
    finally
        cd(original_directory)
        empty!(ARGS)
        append!(ARGS, original_arguments)
        empty!(LOAD_PATH)
        append!(LOAD_PATH, original_load_path)
        for key in setdiff(collect(keys(ENV)), collect(keys(original_environment)))
            delete!(ENV, key)
        end
        for (key, value) in original_environment
            ENV[key] = value
        end
    end
    elapsed = (time_ns() - started) / 1.0e9
    return ExampleRunResult(target.id, elapsed, status, error_message)
end

function _timing_estimates(path::AbstractString)
    estimates = Dict{String,Float64}()
    isfile(path) || return estimates
    for (index, line) in enumerate(eachline(path))
        index == 1 && continue
        fields = split(line, '\t')
        length(fields) >= 4 || continue
        fields[4] == "passed" || continue
        elapsed = tryparse(Float64, fields[3])
        elapsed === nothing || (estimates[fields[1]] = elapsed)
    end
    return estimates
end

function _fallback_cost(root::AbstractString, target::ExampleTarget)
    outputs = joinpath(root, target.directory, "outputs")
    bytes = isdir(outputs) ? sum(
        filesize(joinpath(directory, filename))
        for (directory, _, files) in walkdir(outputs) for filename in files
    ) : 0
    deck_count = count(
        path -> endswith(lowercase(path), ".deck"),
        readdir(joinpath(root, target.directory); join = true),
    )
    return Float64(bytes) / 50_000.0 + 10.0 * deck_count
end

function _prepare_workers(root::AbstractString, count::Int)
    count <= 1 && return Int[]
    engine = abspath(get(
        ENV,
        "AIMORA_ENGINE_PATH",
        joinpath(root, "..", "..", "AIMORA.jl"),
    ))
    environment = Dict(
        "JULIA_NUM_THREADS" => "1",
        "OPENBLAS_NUM_THREADS" => "1",
        "OMP_NUM_THREADS" => "1",
        "AIMORA_ENGINE_PATH" => engine,
        "AIMORA_SOLVER_PATH" => abspath(get(
            ENV,
            "AIMORA_SOLVER_PATH",
            joinpath(dirname(engine), "AIMORASolvers.jl"),
        )),
    )
    worker_ids = addprocs(
        count;
        exeflags = ["--startup-file=no", "--project=$(root)"],
        env = environment,
    )
    qualification_path = joinpath(root, "examples", "Qualification.jl")
    engine_path = environment["AIMORA_ENGINE_PATH"]
    try
        for worker in worker_ids
            fetch(remotecall_eval(
                Main,
                worker,
                quote
                    Base.include(Main, $qualification_path)
                    pushfirst!(LOAD_PATH, $engine_path)
                    using AIMORA
                    using AIMORACases
                    nothing
                end,
            ))
        end
    catch
        rmprocs(worker_ids)
        rethrow()
    end
    return worker_ids
end

function run_examples(
    root::AbstractString,
    targets::Vector{ExampleTarget};
    plan_only::Bool = false,
    timing_path::AbstractString = "",
    release::Bool = false,
    force::Bool = false,
    worker_count::Int = release ? 5 : 1,
)
    isempty(targets) && begin
        println("No runnable example directory was affected")
        return true
    end
    1 <= worker_count <= 5 || error("AIMORA example workers must be between one and five")
    timing_path = isempty(timing_path) ? joinpath(root, ".qualification", "timings.tsv") : timing_path
    estimates = _timing_estimates(timing_path)
    ordered = sort!(copy(targets); by = target -> -get(estimates, target.id, _fallback_cost(root, target)))
    signature_context = _example_signature_context(root)
    signatures = Dict(
        target.id => _example_signature(signature_context, root, target)
        for target in ordered
    )
    pending = ExampleTarget[]
    for target in ordered
        signature = signatures[target.id]
        receipt = _receipt_path(root, target, signature)
        if release && !force && receipt_is_valid(receipt, signature, target.id)
            println("[reuse] $(target.id) exact example receipt")
        else
            push!(pending, target)
        end
    end
    println("Selected AIMORA examples ($(length(targets))); pending=$(length(pending)); workers=$(min(worker_count, max(length(pending), 1)))")
    plan_only && return true
    isempty(pending) && return true

    workers_to_use = min(worker_count, length(pending))
    worker_ids = _prepare_workers(root, workers_to_use)
    temporary_root = release ? mktempdir() : ""
    outputs = Dict(
        target.id => (
            release ? joinpath(temporary_root, target.id) : joinpath(root, target.directory, "outputs")
        ) for target in pending
    )
    try
        results = try
            if workers_to_use == 1
                [_execute_example(root, target, outputs[target.id]) for target in pending]
            else
                pool = WorkerPool(worker_ids)
                pmap(pool, pending; batch_size = 1) do target
                    Main.AIMORAExampleQualification._execute_example(root, target, outputs[target.id])
                end
            end
        finally
            isempty(worker_ids) || rmprocs(worker_ids)
        end

        failures = String[]
        by_id = Dict(target.id => target for target in pending)
        for result in results
            target = by_id[result.id]
            if result.status != "passed"
                _append_timing(timing_path, target, result.elapsed_seconds, "failed")
                push!(failures, "$(result.id): $(result.error_message)")
                println("[fail] $(result.id) $(round(result.elapsed_seconds; digits = 1))s")
                continue
            end
            if release
                try
                    _assert_exact_artifacts(root, target, outputs[target.id])
                catch exception
                    _append_timing(timing_path, target, result.elapsed_seconds, "failed")
                    retained = _retain_failed_artifacts(
                        root,
                        target,
                        signatures[target.id],
                        outputs[target.id],
                    )
                    push!(
                        failures,
                        "$(result.id): $(sprint(showerror, exception)); retained=$(retained)",
                    )
                    println("[fail] $(result.id) artifact comparison; retained=$(retained)")
                    continue
                end
                _write_receipt(
                    root,
                    target,
                    signatures[target.id],
                    result.elapsed_seconds,
                )
            end
            _append_timing(timing_path, target, result.elapsed_seconds, "passed")
            println("[ok] $(result.id) $(round(result.elapsed_seconds; digits = 1))s")
        end
        isempty(failures) || error("AIMORA example qualification failed:\n" * join(failures, "\n"))
        return true
    finally
        release && isdir(temporary_root) && rm(temporary_root; recursive = true)
    end
end

end
