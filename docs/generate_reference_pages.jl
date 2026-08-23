module AIMORAReferenceGenerator

using TOML

export generate_reference_pages

const GENERATED_DIRNAME = "generated"

function _escape_cell(value)
    text = replace(string(value), "\n" => " ", "\r" => " ", "|" => "\\|")
    return strip(text)
end

function _logical_owner(root::AbstractString, path::AbstractString)
    relative = relpath(path, root)
    stem = splitext(relative)[1]
    return replace(stem, '\\' => '/', r"^src/" => "")
end

function _declaration_at(lines::Vector{String}, index::Int)
    line = lines[index]
    patterns = (
        (:struct, r"^\s*(?:Base\.)?@kwdef\s+(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)"),
        (:struct, r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)"),
        (:abstract_type, r"^\s*abstract\s+type\s+([A-Za-z_][A-Za-z0-9_]*)"),
        (:primitive_type, r"^\s*primitive\s+type\s+([A-Za-z_][A-Za-z0-9_]*)"),
        (:enum, r"^\s*@enum\s+([A-Za-z_][A-Za-z0-9_]*)"),
    )
    for (kind, pattern) in patterns
        match_result = match(pattern, line)
        match_result === nothing || return (kind = kind, name = match_result.captures[1])
    end
    return nothing
end

function _declared_fields(lines::Vector{String}, index::Int, kind::Symbol)
    values = String[]
    for cursor in (index + 1):min(length(lines), index + 180)
        stripped = strip(lines[cursor])
        stripped == "end" && break
        startswith(stripped, "function ") && break
        startswith(stripped, "Base.") && !isempty(values) && break
        if kind == :enum
            enum_match = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*(?:=\s*[-+0-9]+)?\s*,?$", stripped)
            enum_match === nothing || push!(values, enum_match.captures[1])
            continue
        end
        field_match = match(r"^([A-Za-z_][A-Za-z0-9_]*)::([^=]+?)(?:\s*=\s*(.*))?$", stripped)
        if field_match !== nothing
            field_name = field_match.captures[1]
            field_type = strip(field_match.captures[2])
            default = field_match.captures[3]
            rendered = "`$(field_name)::$(field_type)`"
            default === nothing || (rendered *= " = `$(strip(default))`")
            push!(values, rendered)
        elseif !isempty(values) && !isempty(stripped) && !startswith(stripped, "#")
            break
        end
    end
    return unique(values)
end

function _exports(lines::Vector{String})
    symbols = String[]
    collecting = false
    for line in lines
        stripped = strip(split(line, '#'; limit = 2)[1])
        if startswith(stripped, "export ")
            collecting = true
            stripped = strip(stripped[8:end])
        elseif collecting
            if isempty(stripped)
                collecting = false
                continue
            elseif occursin(r"^(?:const|module|baremodule|struct|mutable\s+struct|abstract\s+type|primitive\s+type|function|include|using|import|end|@)", stripped)
                collecting = false
                continue
            end
        else
            continue
        end
        for candidate in split(stripped, ',')
            name = strip(candidate)
            occursin(r"^[A-Za-z_][A-Za-z0-9_!]*$", name) && push!(symbols, name)
        end
        endswith(stripped, ',') || (collecting = false)
    end
    return sort!(unique(symbols))
end

function _inventory(root::AbstractString, directory::AbstractString)
    records = NamedTuple[]
    isdir(directory) || return records
    paths = sort(filter(path -> endswith(path, ".jl"), collect(Iterators.flatten(
        (joinpath(current, file) for file in files) for (current, _, files) in walkdir(directory)
    ))))
    for path in paths
        lines = readlines(path)
        declarations = NamedTuple[]
        for index in eachindex(lines)
            declaration = _declaration_at(lines, index)
            declaration === nothing && continue
            push!(declarations, (
                name = declaration.name,
                kind = declaration.kind,
                fields = _declared_fields(lines, index, declaration.kind),
            ))
        end
        push!(records, (
            owner = _logical_owner(root, path),
            declarations = declarations,
            exports = _exports(lines),
            line_count = length(lines),
        ))
    end
    return records
end

function _family(owner::AbstractString)
    name = lowercase(owner)
    occursin("transformer", name) && return "Transformers and magnetic apparatus"
    occursin("reactor", name) && return "Reactors"
    occursin("machine", name) && return "Rotating machines and controls"
    (occursin("line", name) || occursin("cable", name)) && return "Lines, cables, fitting, and history"
    (occursin("bridge", name) || occursin("inverter", name) || occursin("vsc", name) || occursin("semiconductor", name)) && return "Power-electronic converters"
    occursin("nonlinear", name) && return "Nonlinear network devices"
    occursin("switch", name) && return "Switching and event devices"
    (occursin("control", name) || occursin("tacs", name)) && return "Controls and sampled tasks"
    occursin("branch", name) && return "Network primitives"
    return "Other public model owners"
end

function _write_model_index(path::AbstractString, records)
    declaration_count = sum(length(record.declarations) for record in records)
    export_count = sum(length(record.exports) for record in records)
    open(path, "w") do io
        println(io, "# Generated Model Declaration Index")
        println(io)
        println(io, "This page is generated from every Julia source owner below the public engine's model directory. It is a traceability index, not a replacement for the engineering explanations in [Model Library](../model-reference.md). Regenerate it whenever the engine revision changes.")
        println(io)
        println(io, "- Source owners scanned: **$(length(records))**")
        println(io, "- Type and enum declarations found: **$(declaration_count)**")
        println(io, "- Explicitly exported symbols found: **$(export_count)**")
        println(io)
        println(io, "## Family coverage")
        println(io)
        grouped = Dict{String,Vector{Any}}()
        for record in records
            push!(get!(grouped, _family(record.owner), Any[]), record)
        end
        println(io, "| Family | Source owners | Declarations |")
        println(io, "|---|---:|---:|")
        for family in sort(collect(keys(grouped)))
            group = grouped[family]
            println(io, "| $(_escape_cell(family)) | $(length(group)) | $(sum(length(item.declarations) for item in group)) |")
        end
        for family in sort(collect(keys(grouped)))
            println(io)
            println(io, "## $family")
            for record in grouped[family]
                println(io)
                println(io, "### `$(record.owner)`")
                println(io)
                println(io, "Public source size: $(record.line_count) lines.")
                if isempty(record.declarations)
                    println(io)
                    println(io, "No concrete type declaration was detected in this owner; it supplies functions, composition, or include-level organization.")
                else
                    println(io)
                    println(io, "| Declaration | Kind | Declared fields or enum members |")
                    println(io, "|---|---|---|")
                    for declaration in record.declarations
                        fields = isempty(declaration.fields) ? "—" : join(declaration.fields, ", ")
                        println(io, "| `$(declaration.name)` | `$(declaration.kind)` | $(_escape_cell(fields)) |")
                    end
                end
                if !isempty(record.exports)
                    println(io)
                    println(io, "**Explicit exports:** ", join(("`$(name)`" for name in record.exports), ", "), ".")
                end
            end
        end
        println(io)
        println(io, "## Completeness rule")
        println(io)
        println(io, "A new model owner or declaration must appear here after regeneration and must also receive an engineering description, validity statement, result contract, and at least one verification route before it is presented as a supported user model.")
    end
end

function _write_deck_index(path::AbstractString, records)
    declaration_count = sum(length(record.declarations) for record in records)
    open(path, "w") do io
        println(io, "# Generated Deck and Card Declaration Index")
        println(io)
        println(io, "This page is generated from every public deck-parser source owner. Use [Deck and Card Reference](../deck-card-reference.md) for syntax policy, units, continuations, diagnostics, and execution semantics.")
        println(io)
        println(io, "- Parser owners scanned: **$(length(records))**")
        println(io, "- Typed declarations found: **$(declaration_count)**")
        for record in records
            println(io)
            println(io, "## `$(record.owner)`")
            println(io)
            println(io, "Public source size: $(record.line_count) lines.")
            if isempty(record.declarations)
                println(io)
                println(io, "This owner contributes parsing, continuation, dispatch, query, or validation functions without a directly detected concrete type.")
            else
                println(io)
                println(io, "| Card/parser declaration | Kind | Declared fields or enum members |")
                println(io, "|---|---|---|")
                for declaration in record.declarations
                    fields = isempty(declaration.fields) ? "—" : join(declaration.fields, ", ")
                    println(io, "| `$(declaration.name)` | `$(declaration.kind)` | $(_escape_cell(fields)) |")
                end
            end
            if !isempty(record.exports)
                println(io)
                println(io, "**Explicit exports:** ", join(("`$(name)`" for name in record.exports), ", "), ".")
            end
        end
        println(io)
        println(io, "## Parser coverage rule")
        println(io)
        println(io, "Every accepted card family must have a typed representation or a documented dispatch owner, deterministic validation, an example deck, and an error message that identifies the offending section and field. Unknown cards must be rejected rather than silently ignored.")
    end
end

function _status_meaning(status)
    status == :implemented && return "Callable and expected to produce a typed result for valid supported input."
    status == :prototype && return "Experimental interface; behavior and qualification may change."
    status == :legacy_reference && return "Retained for comparison or historical qualification, not the production execution path."
    return "Declared roadmap interface only; callers must expect a not-implemented result."
end

function _write_study_catalog(path::AbstractString, engine_module)
    catalog = getproperty(engine_module, :StudyCatalog)
    studies = collect(getproperty(catalog, :available_studies)())
    sort!(studies; by = study -> (string(getproperty(study, :status)), string(getproperty(study, :domain)), string(getproperty(study, :id))))
    counts = Dict{Symbol,Int}()
    for study in studies
        status = getproperty(study, :status)
        counts[status] = get(counts, status, 0) + 1
    end
    open(path, "w") do io
        println(io, "# Complete Study Catalog")
        println(io)
        println(io, "This page is generated from the engine's typed study catalog. Status is normative: a declared study name does not imply that a numerical implementation exists.")
        println(io)
        println(io, "These counts measure top-level callable study APIs. They are not an overall product-completion percentage and do not count the model, event, solver, restart, converter, machine, line, transformer, control, or validation capabilities implemented inside the `emt` study as separate studies.")
        println(io)
        println(io, "- Total descriptors: **$(length(studies))**")
        println(io, "- Implemented top-level study APIs: **$(get(counts, :implemented, 0)) of $(length(studies))**")
        for status in sort(collect(keys(counts)); by = string)
            println(io, "- `$(status)`: **$(counts[status])**")
        end
        println(io)
        println(io, "| Study ID | Name | Domain | Maturity | Execution meaning |")
        println(io, "|---|---|---|---|---|")
        for study in studies
            id = getproperty(study, :id)
            name = getproperty(study, :name)
            domain = getproperty(study, :domain)
            status = getproperty(study, :status)
            println(io, "| `$(id)` | $(_escape_cell(name)) | `$(domain)` | `$(status)` | $(_escape_cell(_status_meaning(status))) |")
        end
        println(io)
        println(io, "## Status handling")
        println(io)
        println(io, "Automation must inspect the descriptor and returned result status. Planned studies must fail transparently with a typed `not_implemented` outcome; they must never return fabricated engineering values or silently substitute a different study.")
    end
end

function _bool_text(value)
    value === true && return "yes"
    value === false && return "no"
    return string(value)
end

function _write_case_catalog(path::AbstractString, repository_root::AbstractString)
    catalog_path = joinpath(repository_root, "AIMORACases", "examples", "catalog.toml")
    isfile(catalog_path) || error("Case catalog not found at $(catalog_path)")
    parsed = TOML.parsefile(catalog_path)
    cases = collect(get(parsed, "case", Any[]))
    sort!(cases; by = case -> (string(get(case, "study", "")), string(get(case, "id", ""))))
    study_counts = Dict{String,Int}()
    for case in cases
        study = string(get(case, "study", "unknown"))
        study_counts[study] = get(study_counts, study, 0) + 1
    end
    open(path, "w") do io
        println(io, "# Complete Runnable Case Catalog")
        println(io)
        println(io, "This page is generated from the canonical `aimora-examples-v2` catalog. It documents every registered public case without inventing numerical results. Case-specific reports and committed artifacts remain the authority for actual values.")
        println(io)
        println(io, "- Registered cases: **$(length(cases))**")
        println(io, "- Study groups: **$(length(study_counts))**")
        println(io, "- Solver-required cases: **$(count(case -> get(case, "requires_solver", false) === true, cases))**")
        println(io, "- Historical-reference-compatible cases: **$(count(case -> get(case, "reference_compatible", false) === true, cases))**")
        println(io)
        println(io, "## Catalog by study")
        println(io)
        println(io, "| Study | Cases |")
        println(io, "|---|---:|")
        for study in sort(collect(keys(study_counts)))
            println(io, "| `$(study)` | $(study_counts[study]) |")
        end
        println(io)
        println(io, "## Standard execution and review")
        println(io)
        println(io, "From the Resources repository root, run a case through its local Makefile:")
        println(io)
        println(io, "```bash")
        println(io, "make -C AIMORACases/<case-directory> run")
        println(io, "```")
        println(io)
        println(io, "Review the case README before execution, then inspect its `outputs/` directory, typed summary, diagnostics, and any qualification comparison. A successful process exit is necessary but not sufficient: energy, KCL, passivity, convergence, event, and restart evidence must satisfy the case's declared acceptance contract.")
        for case in cases
            id = string(get(case, "id", "unnamed"))
            study = string(get(case, "study", "unknown"))
            input = string(get(case, "path", ""))
            entrypoint = string(get(case, "entrypoint", input))
            description = string(get(case, "description", "No description supplied."))
            result_kind = string(get(case, "result_kind", "unspecified"))
            source_ids = get(case, "source_ids", Any[])
            case_directory = dirname(entrypoint)
            command = "make -C AIMORACases/$(case_directory) run"
            println(io)
            println(io, "## `$(id)`")
            println(io)
            println(io, description)
            println(io)
            println(io, "| Property | Value |")
            println(io, "|---|---|")
            println(io, "| Study | `$(study)` |")
            println(io, "| Primary input | `$(input)` |")
            println(io, "| Entrypoint | `$(entrypoint)` |")
            println(io, "| Result contract | `$(result_kind)` |")
            println(io, "| Production solver required | $(_bool_text(get(case, "requires_solver", false))) |")
            println(io, "| Historical reference compatible | $(_bool_text(get(case, "reference_compatible", false))) |")
            println(io, "| Evidence/source identifiers | $(_escape_cell(join(string.(source_ids), ", "))) |")
            println(io)
            println(io, "```bash")
            println(io, command)
            println(io, "```")
            println(io)
            println(io, "**Interpretation:** relate the generated quantities and plots to the stated phenomenon above. Do not infer accuracy from visual plausibility alone.")
            println(io)
            println(io, "**Acceptance:** execution must complete deterministically; declared outputs must be present; warnings must be reviewed; and the case-specific numerical, event, conservation, passivity, or restart checks must pass.")
        end
    end
end

function generate_reference_pages(engine_path::AbstractString, engine_module)
    repository_root = normpath(joinpath(@__DIR__, ".."))
    output_dir = joinpath(@__DIR__, "src", GENERATED_DIRNAME)
    mkpath(output_dir)

    model_records = _inventory(engine_path, joinpath(engine_path, "src", "models"))
    deck_records = _inventory(engine_path, joinpath(engine_path, "src", "io", "deck_parser"))

    _write_model_index(joinpath(output_dir, "model-index.md"), model_records)
    _write_deck_index(joinpath(output_dir, "deck-card-index.md"), deck_records)
    _write_study_catalog(joinpath(output_dir, "study-catalog.md"), engine_module)
    _write_case_catalog(joinpath(output_dir, "case-catalog.md"), repository_root)

    return (
        model_owners = length(model_records),
        deck_owners = length(deck_records),
        output_dir = output_dir,
    )
end

function _resolve_engine_path()
    configured = strip(get(ENV, "AIMORA_DOCS_ENGINE_PATH", ""))
    workspace_candidate = normpath(joinpath(@__DIR__, "..", "..", "AIMORA.jl"))
    if !isempty(configured)
        return abspath(configured)
    elseif isfile(joinpath(workspace_candidate, "src", "AIMORA.jl"))
        return workspace_candidate
    end
    error("Place AIMORA.jl beside this checkout or set AIMORA_DOCS_ENGINE_PATH")
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    engine_path = AIMORAReferenceGenerator._resolve_engine_path()
    pushfirst!(LOAD_PATH, engine_path)
    using AIMORA
    result = AIMORAReferenceGenerator.generate_reference_pages(engine_path, AIMORA)
    println("Generated AIMORA reference pages in $(result.output_dir)")
end
