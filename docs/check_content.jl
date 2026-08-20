#!/usr/bin/env julia

using TOML

resources_root = normpath(joinpath(@__DIR__, ".."))
docs_root = joinpath(@__DIR__, "src")
cases_root = joinpath(resources_root, "AIMORACases.jl")
examples_root = joinpath(cases_root, "examples")
templates_root = joinpath(resources_root, "report-templates", "v1")

required_manual_pages = [
    "professional-manual.md",
    "architecture-reference.md",
    "study-reference.md",
    "model-reference.md",
    "deck-card-reference.md",
    "example-catalog.md",
    "solver-reference.md",
    "results-and-reporting.md",
    "troubleshooting.md",
    "source-coverage.md",
    "glossary.md",
]

errors = String[]
warnings = String[]

for page in required_manual_pages
    path = joinpath(docs_root, page)
    isfile(path) || push!(errors, "missing manual page: $page")
    isfile(path) && filesize(path) < 500 && push!(errors, "manual page is not substantive: $page")
end

catalog_path = joinpath(examples_root, "catalog.toml")
if !isfile(catalog_path)
    push!(errors, "missing example catalogue: $catalog_path")
else
    catalogue = TOML.parsefile(catalog_path)
    rows = get(catalogue, "case", Any[])
    seen = Set{String}()
    for row in rows
        id = String(get(row, "id", ""))
        isempty(id) && begin
            push!(errors, "catalogue row has no case id")
            continue
        end
        id in seen && push!(errors, "duplicate case id: $id")
        push!(seen, id)
        entrypoint = String(get(row, "entrypoint", ""))
        primary = String(get(row, "path", entrypoint))
        isempty(entrypoint) && push!(errors, "$id has no entrypoint")
        !isempty(entrypoint) && !isfile(joinpath(cases_root, entrypoint)) &&
            push!(errors, "$id entrypoint does not exist: $entrypoint")
        !isempty(primary) && !isfile(joinpath(cases_root, primary)) &&
            push!(errors, "$id primary input does not exist: $primary")
        case_directory = isempty(entrypoint) ? "" : dirname(joinpath(cases_root, entrypoint))
        if !isempty(case_directory)
            readme = joinpath(case_directory, "README.md")
            isfile(readme) || push!(errors, "$id has no README beside its entrypoint")
            isfile(readme) && filesize(readme) < 300 && push!(errors, "$id README is not substantive")
            output_directory = joinpath(case_directory, "outputs")
            if !isdir(output_directory) || isempty(readdir(output_directory))
                push!(warnings, "$id has no committed canonical outputs")
            end
        end
        isempty(get(row, "description", "")) && push!(errors, "$id has no description")
        isempty(get(row, "result_kind", "")) && push!(errors, "$id has no result_kind")
        isempty(get(row, "source_ids", Any[])) && push!(errors, "$id has no source/provenance IDs")
    end
    println("Registered public cases checked: ", length(rows))
end

manifest_path = joinpath(templates_root, "manifest.toml")
if !isfile(manifest_path)
    push!(errors, "missing report-template manifest")
else
    manifest = TOML.parsefile(manifest_path)
    rows = get(manifest, "template", Any[])
    seen = Set{String}()
    for row in rows
        id = String(get(row, "id", ""))
        path = String(get(row, "path", ""))
        isempty(id) && push!(errors, "template row has no id")
        id in seen && push!(errors, "duplicate template id: $id")
        push!(seen, id)
        template_path = joinpath(templates_root, path)
        isfile(template_path) || push!(errors, "template file is missing: $path")
        if isfile(template_path)
            template = TOML.parsefile(template_path)
            for key in ("id", "version", "licence", "family", "required_roles", "output_profiles")
                haskey(template, key) || push!(errors, "$id template is missing field '$key'")
            end
        end
        isempty(get(row, "licence", "")) && push!(errors, "$id manifest row has no licence")
        isempty(get(row, "trust", "")) && push!(errors, "$id manifest row has no trust class")
    end
    println("Report templates checked: ", length(rows))
end

link_pattern = r"\[[^\]]*\]\(([^\)]+)\)"
for page in filter(name -> endswith(name, ".md"), readdir(docs_root))
    text = read(joinpath(docs_root, page), String)
    for match in eachmatch(link_pattern, text)
        target = split(match.captures[1], '#'; limit = 2)[1]
        isempty(target) && continue
        startswith(target, ("http://", "https://", "mailto:", "#")) && continue
        target_path = normpath(joinpath(docs_root, target))
        ispath(target_path) || push!(errors, "$page has broken local link: $target")
    end
    occursin(r"/(home|Users|mnt|tmp)/", text) && push!(errors, "$page contains an absolute workstation path")
    occursin("private-user-images.githubusercontent.com", text) && push!(errors, "$page contains a private attachment URL")
end

for message in warnings
    println("WARNING: ", message)
end
if !isempty(errors)
    foreach(message -> println(stderr, "ERROR: ", message), errors)
    error("documentation content gate failed with $(length(errors)) error(s)")
end

println("Manual pages checked: ", length(required_manual_pages))
println("AIMORA documentation content gate: PASS")
