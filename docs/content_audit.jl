using TOML

const DOCS_DIR = @__DIR__
const SRC_DIR = joinpath(DOCS_DIR, "src")
const ENGINE_PATH = let
    configured = strip(get(ENV, "AIMORA_DOCS_ENGINE_PATH", ""))
    workspace_candidate = normpath(joinpath(DOCS_DIR, "..", "..", "AIMORA.jl"))
    if !isempty(configured)
        abspath(configured)
    elseif isfile(joinpath(workspace_candidate, "src", "AIMORA.jl"))
        workspace_candidate
    else
        error("Place AIMORA.jl beside AIMORAResources or set AIMORA_DOCS_ENGINE_PATH")
    end
end

const REQUIRED_MANUALS = [
    "index.md",
    "getting-started.md",
    "professional-workflow.md",
    "architecture.md",
    "study-reference.md",
    "model-reference.md",
    "deck-card-reference.md",
    "solver-reference.md",
    "results-and-validation.md",
    "troubleshooting.md",
    "glossary.md",
    joinpath("generated", "study-catalog.md"),
    joinpath("generated", "model-index.md"),
    joinpath("generated", "deck-card-index.md"),
    joinpath("generated", "case-catalog.md"),
]

const PLACEHOLDER_PATTERNS = [
    r"(?i)\bTODO\b",
    r"(?i)\bTBD\b",
    r"(?i)coming soon",
    r"(?i)lorem ipsum",
    r"(?i)insert (?:text|content|figure) here",
]

function logical_owner(root::AbstractString, path::AbstractString)
    relative = splitext(relpath(path, root))[1]
    return replace(relative, '\\' => '/', r"^src/" => "")
end

function jl_files(directory::AbstractString)
    isdir(directory) || return String[]
    return sort(collect(Iterators.flatten(
        (joinpath(current, file) for file in files if endswith(file, ".jl"))
        for (current, _, files) in walkdir(directory)
    )))
end

function declarations(path::AbstractString)
    names = String[]
    patterns = [
        r"^\s*(?:Base\.)?@kwdef\s+(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)"m,
        r"^\s*(?:mutable\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)"m,
        r"^\s*abstract\s+type\s+([A-Za-z_][A-Za-z0-9_]*)"m,
        r"^\s*primitive\s+type\s+([A-Za-z_][A-Za-z0-9_]*)"m,
        r"^\s*@enum\s+([A-Za-z_][A-Za-z0-9_]*)"m,
    ]
    text = read(path, String)
    for pattern in patterns
        for match_result in eachmatch(pattern, text)
            push!(names, match_result.captures[1])
        end
    end
    return sort!(unique(names))
end

failures = String[]

for relative in REQUIRED_MANUALS
    path = joinpath(SRC_DIR, relative)
    if !isfile(path)
        push!(failures, "missing required documentation page: $(relative)")
        continue
    end
    text = read(path, String)
    length(text) >= 300 || push!(failures, "documentation page is unexpectedly small: $(relative)")
    startswith(strip(text), "# ") || push!(failures, "documentation page lacks a level-one title: $(relative)")
    for pattern in PLACEHOLDER_PATTERNS
        occursin(pattern, text) && push!(failures, "placeholder text detected in $(relative): $(pattern)")
    end
end

model_page_path = joinpath(SRC_DIR, "generated", "model-index.md")
if isfile(model_page_path)
    model_page = read(model_page_path, String)
    for path in jl_files(joinpath(ENGINE_PATH, "src", "models"))
        owner = logical_owner(ENGINE_PATH, path)
        occursin("### `$(owner)`", model_page) || push!(failures, "model source owner absent from generated index: $(owner)")
        for name in declarations(path)
            occursin("`$(name)`", model_page) || push!(failures, "model declaration absent from generated index: $(owner)::$(name)")
        end
    end
end

deck_page_path = joinpath(SRC_DIR, "generated", "deck-card-index.md")
if isfile(deck_page_path)
    deck_page = read(deck_page_path, String)
    for path in jl_files(joinpath(ENGINE_PATH, "src", "io", "deck_parser"))
        owner = logical_owner(ENGINE_PATH, path)
        occursin("## `$(owner)`", deck_page) || push!(failures, "deck/parser source owner absent from generated index: $(owner)")
        for name in declarations(path)
            occursin("`$(name)`", deck_page) || push!(failures, "deck/parser declaration absent from generated index: $(owner)::$(name)")
        end
    end
end

catalog_path = normpath(joinpath(DOCS_DIR, "..", "AIMORACases.jl", "examples", "catalog.toml"))
case_page_path = joinpath(SRC_DIR, "generated", "case-catalog.md")
if isfile(catalog_path) && isfile(case_page_path)
    parsed = TOML.parsefile(catalog_path)
    cases = get(parsed, "case", Any[])
    case_page = read(case_page_path, String)
    isempty(cases) && push!(failures, "canonical case catalog is empty")
    ids = String[]
    for case in cases
        id = string(get(case, "id", ""))
        isempty(id) && push!(failures, "case without id in canonical catalog")
        id in ids && push!(failures, "duplicate case id in canonical catalog: $(id)")
        push!(ids, id)
        occursin("## `$(id)`", case_page) || push!(failures, "registered case absent from generated manual: $(id)")
        for key in ("study", "path", "entrypoint", "description", "result_kind")
            haskey(case, key) || push!(failures, "case $(id) is missing required catalog key: $(key)")
        end
    end
end

study_source = joinpath(ENGINE_PATH, "src", "studies", "catalog.jl")
study_page_path = joinpath(SRC_DIR, "generated", "study-catalog.md")
if isfile(study_source) && isfile(study_page_path)
    study_page = read(study_page_path, String)
    source_text = read(study_source, String)
    ids = sort!(unique(match_result.captures[1] for match_result in eachmatch(r"StudyDescriptor\(\s*:\s*([A-Za-z_][A-Za-z0-9_]*)", source_text)))
    isempty(ids) && push!(failures, "no study descriptors detected in public study catalog source")
    for id in ids
        occursin("`$(id)`", study_page) || push!(failures, "study descriptor absent from generated manual: $(id)")
    end
end

if isempty(failures)
    println("Documentation content audit passed.")
    println("  Required manual pages: $(length(REQUIRED_MANUALS))")
    println("  Model source owners: $(length(jl_files(joinpath(ENGINE_PATH, "src", "models"))))")
    println("  Deck/parser owners: $(length(jl_files(joinpath(ENGINE_PATH, "src", "io", "deck_parser"))))")
else
    println(stderr, "Documentation content audit failed with $(length(failures)) issue(s):")
    for failure in failures
        println(stderr, "  - ", failure)
    end
    error("documentation content audit failed")
end
