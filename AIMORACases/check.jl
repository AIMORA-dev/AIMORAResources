#!/usr/bin/env julia

using AIMORACases
using TOML

const ROOT = @__DIR__

fail(message) = error("AIMORA case package check failed: $(message)")

for relative_path in (
    "Project.toml",
    "README.md",
    "examples/catalog.toml",
    "examples/source_coverage.toml",
    "examples/SOURCE_COVERAGE.md",
    "src/AIMORACases.jl",
    "test/runtests.jl",
    "examples/README.md",
    "examples/list_cases.jl",
    "examples/Qualification.jl",
    "examples/run_examples.jl",
    "examples/support/ExampleSupport.jl",
    "examples/support/CatalogDeckExample.jl",
    "examples/support/ClassicEMTPExample.jl",
    "examples/emt/inverter/run.jl",
    "examples/emt/user_defined_components/run.jl",
    "examples/emt/user_defined_components/public_sampled_saturating_lag.jl",
    "examples/emt/user_defined_components/public_cubic_current_branch.jl",
    "examples/emt/user_defined_components/public_series_rl_companion.jl",
    "examples/emt/generated_ieee13_deck/ieee13_minimum_core.deck",
)
    isfile(joinpath(ROOT, relative_path)) || fail("missing $(relative_path)")
end

project = TOML.parsefile(joinpath(ROOT, "Project.toml"))
get(project, "name", nothing) == "AIMORACases" ||
    fail("Project.toml name is not AIMORACases")

cases = AIMORACases.available_cases()
isempty(cases) && fail("case catalog is empty")
for case in cases
    isfile(AIMORACases.case_path(case.id)) || fail("missing case file for $(case.id)")
    isempty(strip(case.description)) && fail("case $(case.id) has no description")
end
catalog = TOML.parsefile(joinpath(ROOT, "examples", "catalog.toml"))
get(catalog, "schema", nothing) == "aimora-examples-v2" ||
    fail("example catalog schema is not aimora-examples-v2")
catalog_rows = catalog["case"]
include(joinpath(ROOT, "examples", "Qualification.jl"))
qualification_targets = AIMORAExampleQualification.example_targets(ROOT)
length(qualification_targets) == length(catalog_rows) ||
    fail("qualification runner does not cover every catalog example")
catalog_directories = String[]
catalog_rows_by_directory = Dict{String,Any}()
for row in catalog_rows
    for field in ("id", "study", "path", "entrypoint", "description", "result_kind")
        haskey(row, field) || fail("catalog row is missing $(field)")
        isempty(strip(String(row[field]))) && fail("catalog row has empty $(field)")
    end
    entrypoint = normpath(joinpath(ROOT, String(row["entrypoint"])))
    isfile(entrypoint) || fail("catalog entrypoint does not exist: $(row["entrypoint"])")
    basename(entrypoint) == "run.jl" ||
        fail("catalog entrypoint is not a run.jl: $(row["entrypoint"])")
    example_root = dirname(entrypoint)
    push!(catalog_directories, example_root)
    catalog_rows_by_directory[example_root] = row
end
length(unique(String(row["id"]) for row in catalog_rows)) == length(catalog_rows) ||
    fail("catalog example ids are not unique")

coverage = TOML.parsefile(joinpath(ROOT, "examples", "source_coverage.toml"))
get(coverage, "schema", nothing) == "aimora-source-coverage-v1" ||
    fail("source coverage schema is not aimora-source-coverage-v1")
String(get(coverage, "status", "")) == "audited" ||
    fail("source coverage must be audited before publication")
coverage_rows = get(coverage, "source", Any[])
isempty(coverage_rows) && fail("source coverage is empty")
Int(get(coverage, "source_count", -1)) == length(coverage_rows) ||
    fail("source_count does not match source coverage rows")

coverage_ids = String[]
coverage_by_id = Dict{String,Any}()
allowed_kinds = Set((
    "aimora_reference",
    "atpdraw_case",
    "atpdraw_exa_project",
    "canonical_case_input",
    "claimed_external_case",
    "claimed_translation_packet",
    "classic_case",
    "classic_case_origin",
    "public_testset",
    "translation_capability_packet",
    "validation_fixture",
    "validation_suite",
))
allowed_dispositions = Set((
    "example",
    "gallery",
    "negative_test",
    "not_a_deck",
    "oracle_only",
    "pending_export",
    "source_missing",
    "validation_only",
))
catalog_ids = Set(String(row["id"]) for row in catalog_rows)
for row in coverage_rows
    for field in ("id", "owner", "kind", "path", "disposition", "example_ids", "reason")
        haskey(row, field) || fail("coverage row is missing $(field)")
    end
    source_id = String(row["id"])
    owner = String(row["owner"])
    kind = String(row["kind"])
    path = String(row["path"])
    disposition = String(row["disposition"])
    example_ids = String.(row["example_ids"])
    reason = String(row["reason"])

    isempty(strip(source_id)) && fail("coverage row has an empty id")
    isempty(strip(owner)) && fail("coverage row $(source_id) has an empty owner")
    isempty(strip(reason)) && fail("coverage row $(source_id) has no reason")
    kind in allowed_kinds || fail("coverage row $(source_id) has unknown kind $(kind)")
    disposition in allowed_dispositions ||
        fail("coverage row $(source_id) has unknown disposition $(disposition)")
    length(unique(example_ids)) == length(example_ids) ||
        fail("coverage row $(source_id) repeats an example id")
    all(in(catalog_ids), example_ids) ||
        fail("coverage row $(source_id) references an unknown example")

    maps_to_examples = disposition in ("example", "gallery")
    maps_to_examples == !isempty(example_ids) ||
        fail("coverage row $(source_id) has an inconsistent disposition/example mapping")
    path_may_be_empty = disposition in ("not_a_deck", "source_missing")
    (path_may_be_empty || !isempty(strip(path))) ||
        fail("coverage row $(source_id) is missing its source path")
    (!path_may_be_empty || isempty(strip(path))) ||
        fail("coverage row $(source_id) should not claim a source path")

    if owner == "AIMORACases"
        local_path = first(split(path, '#'; limit = 2))
        ispath(joinpath(ROOT, local_path)) ||
            fail("coverage row $(source_id) has a stale AIMORACases path: $(path)")
    elseif kind == "aimora_reference"
        owner == "AIMORAResources/AIMORAReferenceModels" ||
            fail("AIMORA reference $(source_id) has an invalid owner")
        startswith(path, "src/") && endswith(path, ".jl") ||
            fail("AIMORA reference $(source_id) has an invalid source path")
        reference_path = joinpath(ROOT, "..", "AIMORAReferenceModels", path)
        isfile(reference_path) ||
            fail("AIMORA reference $(source_id) has a stale source path: $(path)")
    elseif kind == "validation_fixture"
        startswith(path, "tests/fixtures/") ||
            fail("validation fixture $(source_id) has an invalid path")
    elseif kind == "validation_suite"
        startswith(path, "tests/suite/") ||
            fail("validation suite $(source_id) has an invalid path")
    elseif kind == "atpdraw_case"
        startswith(path, "https://www.atpdraw.net/showpost.php?") ||
            fail("official ATPDraw case $(source_id) lacks its official URL")
    elseif kind == "atpdraw_exa_project"
        occursin("ATPDraw73_Image.zip!/", path) ||
            fail("bundled ATPDraw project $(source_id) lacks an archive-member path")
        endswith(lowercase(path), ".acp") ||
            fail("bundled ATPDraw project $(source_id) is not an ACP member")
    end

    push!(coverage_ids, source_id)
    coverage_by_id[source_id] = row
end
length(unique(coverage_ids)) == length(coverage_ids) ||
    fail("source coverage ids are not unique")

function field_counts(rows, field)
    counts = Dict{String,Int}()
    for row in rows
        value = String(row[field])
        counts[value] = get(counts, value, 0) + 1
    end
    return counts
end

for (field, table_name) in (
    ("kind", "counts_by_kind"),
    ("disposition", "counts_by_disposition"),
)
    declared = Dict(String(key) => Int(value) for (key, value) in coverage[table_name])
    declared == field_counts(coverage_rows, field) ||
        fail("$(table_name) does not match source coverage rows")
end

for row in catalog_rows
    example_id = String(row["id"])
    for source_id in String.(get(row, "source_ids", String[]))
        haskey(coverage_by_id, source_id) ||
            fail("catalog example $(example_id) has unknown source id $(source_id)")
        example_id in String.(coverage_by_id[source_id]["example_ids"]) ||
            fail("source $(source_id) does not map back to catalog example $(example_id)")
    end
end

# Stronger cross-owner checks run when this public package is inside the full
# AIMORA workspace. A standalone public clone remains self-contained.
workspace_root = normpath(joinpath(ROOT, ".."))
validation_root = joinpath(workspace_root, "AIMORAValidation")
if isdir(joinpath(validation_root, "tests"))
    expected_suites = Set(
        String(row["path"]) for row in coverage_rows if
        String(row["kind"]) == "validation_suite"
    )
    actual_suites = Set(
        replace(relpath(path, validation_root), '\\' => '/') for path in
        filter(
            path -> isfile(path) && endswith(path, ".jl"),
            readdir(joinpath(validation_root, "tests", "suite"); join = true),
        )
    )
    expected_suites == actual_suites ||
        fail("source coverage does not exactly match AIMORAValidation suite files")

    expected_fixtures = Set(
        String(row["path"]) for row in coverage_rows if
        String(row["kind"]) == "validation_fixture"
    )
    actual_fixtures = Set{String}()
    fixtures_root = joinpath(validation_root, "tests", "fixtures")
    for (directory, _, files) in walkdir(fixtures_root)
        for filename in files
            push!(
                actual_fixtures,
                replace(relpath(joinpath(directory, filename), validation_root), '\\' => '/'),
            )
        end
    end
    expected_fixtures == actual_fixtures ||
        fail("source coverage does not exactly match AIMORAValidation fixtures")
end

engine_root = joinpath(workspace_root, "AIMORA.jl")
if isdir(joinpath(engine_root, "test"))
    for row in coverage_rows
        String(row["owner"]) == "AIMORA.jl" || continue
        source_path, fragment = let parts = split(String(row["path"]), '#'; limit = 2)
            (first(parts), length(parts) == 2 ? last(parts) : "")
        end
        full_path = joinpath(engine_root, source_path)
        isfile(full_path) || fail("coverage row $(row["id"]) has a stale AIMORA.jl path")
        isempty(fragment) || occursin(fragment, read(full_path, String)) ||
            fail("coverage row $(row["id"]) has a stale AIMORA.jl testset fragment")
    end
end

if isfile(joinpath(workspace_root, "LEDGER", "cards_c301_c325.md"))
    cards = read(
        joinpath(workspace_root, "LEDGER", "cards_c301_c325.md"),
        String,
    )
    for row in coverage_rows
        String(row["kind"]) == "translation_capability_packet" || continue
        card = last(split(String(row["id"]), ':'))
        occursin("### $(card) ", cards) ||
            fail("coverage row $(row["id"]) has no authoritative translation card")
    end
end

private_atp_root = joinpath(
    workspace_root,
    "references",
    "review_library",
    "private",
    "ATP-materail",
)
if isdir(private_atp_root)
    unzip = Sys.which("unzip")
    unzip === nothing && fail("unzip is required to verify the private ACP inventory")
    archive_members = Dict{String,Set{String}}()
    for row in coverage_rows
        String(row["kind"]) == "atpdraw_exa_project" || continue
        parts = split(String(row["path"]), "!/"; limit = 2)
        length(parts) == 2 || fail("invalid ACP archive member path for $(row["id"])")
        archive_path, member = parts
        if !haskey(archive_members, archive_path)
            full_archive = joinpath(private_atp_root, archive_path)
            isfile(full_archive) || fail("missing private ACP archive $(archive_path)")
            archive_members[archive_path] = Set(split(read(`$(unzip) -Z1 $(full_archive)`, String), '\n'))
        end
        member in archive_members[archive_path] ||
            fail("missing ACP member $(member) for $(row["id"])")
    end

    official_zip_root = joinpath(
        private_atp_root,
        "official-atpdraw-case-zips",
        "individual",
    )
    for row in coverage_rows
        String(row["kind"]) == "atpdraw_case" || continue
        case_number = replace(String(row["id"]), "atpdraw-official:case-" => "")
        isfile(joinpath(official_zip_root, "case_$(case_number).zip")) ||
            fail("missing archived official ATPDraw case $(case_number)")
    end
end

examples_root = joinpath(ROOT, "examples")
example_directories = String[]
for study_root in sort(filter(isdir, readdir(examples_root; join = true)))
    basename(study_root) == "support" && continue
    for example_root in sort(filter(isdir, readdir(study_root; join = true)))
        push!(example_directories, example_root)
    end
end
isempty(example_directories) && fail("no runnable examples")
for example_root in example_directories
    label = relpath(example_root, examples_root)
    readme_path = joinpath(example_root, "README.md")
    isfile(readme_path) ||
        fail("missing README.md for $(label)")
    isfile(joinpath(example_root, "run.jl")) ||
        fail("missing run.jl for $(label)")
    isfile(joinpath(example_root, "Makefile")) ||
        fail("missing Makefile for $(label)")
    !isdir(joinpath(example_root, "results")) ||
        fail("legacy results directory duplicates canonical outputs for $(label)")

    readme = read(readme_path, String)
    readme_word_count = count(!isempty, split(readme, r"\s+"))
    readme_word_count >= 140 ||
        fail("README for $(label) is not comprehensive (only $(readme_word_count) words)")
    occursin(r"(?im)^## .*\brun\b.*$", readme) ||
        fail("README for $(label) has no run section")
    occursin("make run", readme) ||
        fail("README for $(label) has no local make command")
    occursin(r"(?im)^## .*\b(output|result|artifact)s?\b", readme) ||
        fail("README for $(label) has no result-artifact section")
    occursin(
        r"(?i)interpret|expect|should|confirm|inspect|look for|compare|means|indicat|demonstrat|show",
        readme,
    ) || fail("README for $(label) does not explain how to interpret its result")

    output_root = joinpath(example_root, "outputs")
    isdir(output_root) || fail("missing outputs directory for $(label)")
    output_files = sort(filter(isfile, readdir(output_root; join = true)))
    isempty(output_files) && fail("outputs directory is empty for $(label)")
    for output_file in output_files
        filesize(output_file) > 0 ||
            fail("empty output artifact for $(label): $(basename(output_file))")
    end

    result_kind = String(catalog_rows_by_directory[example_root]["result_kind"])
    text_extensions = Set((".csv", ".json", ".md", ".svg", ".toml", ".txt"))
    for output_file in output_files
        extension = lowercase(splitext(output_file)[2])
        extension in text_extensions || continue
        content = read(output_file, String)
        occursin(r"/home/|/Users/|[A-Za-z]:\\\\", content) &&
            fail(
                "output artifact contains an absolute workstation path: " *
                "$(label)/$(basename(output_file))",
            )
        result_kind == "timing" && continue
        for found in eachmatch(r"elapsed_s\"?\s*[:=]\s*([-+0-9.eE]+)", content)
            value = tryparse(Float64, found.captures[1])
            value === nothing &&
                fail(
                    "output artifact has an invalid elapsed_s value: " *
                    "$(label)/$(basename(output_file))",
                )
            iszero(value) ||
                fail(
                    "scientific output persists nondeterministic elapsed_s: " *
                    "$(label)/$(basename(output_file))",
                )
        end
    end
    extensions = Set(lowercase(splitext(path)[2]) for path in output_files)
    if result_kind == "timing"
        ".json" in extensions ||
            fail("timing example $(label) must write a JSON result")
        occursin(".json", readme) ||
            fail("timing README for $(label) does not document its JSON result")
    else
        ".svg" in extensions ||
            fail("$(result_kind) example $(label) must write an SVG figure")
        !isempty(intersect(extensions, Set((".csv", ".json", ".md", ".toml", ".txt")))) ||
            fail("$(result_kind) example $(label) must write a data or report artifact")
        occursin(".svg", readme) ||
            fail("README for $(label) does not document its SVG figure")
        any(occursin(extension, readme) for extension in (".csv", ".json", ".md", ".toml", ".txt")) ||
            fail("README for $(label) does not document a data or report artifact")
    end
end
Set(catalog_directories) == Set(example_directories) || begin
    uncatalogued = sort(relpath.(setdiff(
        Set(example_directories),
        Set(catalog_directories),
    ), Ref(examples_root)))
    missing_directory = sort(relpath.(setdiff(
        Set(catalog_directories),
        Set(example_directories),
    ), Ref(examples_root)))
    fail(
        "catalog/directory mismatch; uncatalogued=$(join(uncatalogued, ",")); " *
        "missing=$(join(missing_directory, ","))",
    )
end

for (directory, _, files) in walkdir(ROOT)
    for filename in files
        extension = lowercase(splitext(filename)[2])
        extension in (".f", ".for", ".ftn", ".f90", ".f95") &&
            fail("Fortran source belongs in BPAEMTPReference.jl: $(joinpath(directory, filename))")
    end
end

!ispath(joinpath(ROOT, "cases")) ||
    fail("legacy cases directory must not duplicate the organized examples")

for forbidden_path in ("AGENTS.md", "MEMORY.md", "TRANSLATION_MAP.md", ".codex", "runs")
    !ispath(joinpath(ROOT, forbidden_path)) ||
        fail("development-only path is present: $(forbidden_path)")
end

println("AIMORA case package check passed")
