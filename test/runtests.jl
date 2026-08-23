using SHA
using Test
using TOML

const RESOURCES_ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(RESOURCES_ROOT, "tools", "changed_resources.jl"))
using .ChangedResources
include(joinpath(RESOURCES_ROOT, "tools", "baseline_artifact_inventory.jl"))
using .BaselineArtifactInventory

const RESOURCE_PROJECTS = Dict(
    "AIMORACases" => (
        name = "AIMORACases",
        uuid = "c2d99356-2241-4b88-ae11-80a94b927354",
        version = "0.1.0",
    ),
    "AIMORACatalogs" => (
        name = "AIMORACatalogs",
        uuid = "2b6c9f6e-dc5c-4462-b175-cd3ce62f4f80",
        version = "0.1.0",
    ),
    "AIMORAReferenceModels" => (
        name = "AIMORAReferenceModels",
        uuid = "6a268073-c1b2-474c-bd10-49e12d1609a5",
        version = "0.1.0",
    ),
)

function tracked_paths()
    output = read(
        `git -C $RESOURCES_ROOT ls-files --cached --others --exclude-standard -z`,
        String,
    )
    return filter(split(output, '\0')) do path
        !isempty(path) && isfile(joinpath(RESOURCES_ROOT, path))
    end
end

function tree_paths(revision::AbstractString)
    output = read(`git -C $RESOURCES_ROOT ls-tree -r --name-only -z $revision`, String)
    return filter(!isempty, split(output, '\0'))
end

@testset "AIMORA Resources repository contract" begin
    for relative_path in (
        "licensing.toml",
        "resource-index.toml",
        "artifact-policy.toml",
        "provenance/history-map.toml",
        "AIMORACases",
        "AIMORACatalogs",
        "AIMORAReferenceModels",
        "references/bpa_emtp",
        "report-templates",
        "docs",
        "teaching",
        "examples",
        "provenance",
    )
        @test ispath(joinpath(RESOURCES_ROOT, relative_path))
    end

    resource_index = TOML.parsefile(joinpath(RESOURCES_ROOT, "resource-index.toml"))
    @test resource_index["schema"] == "aimora-resource-index-v1"
    resources = resource_index["resource"]
    @test Set(resource["id"] for resource in resources) == Set((
        "cases",
        "catalogs",
        "reference-models",
        "bpa-emtp-reference",
        "external-reference-sources",
        "review-library-policy",
        "report-templates",
        "documentation",
        "teaching",
        "examples",
        "provenance",
    ))
    @test all(ispath(joinpath(RESOURCES_ROOT, resource["path"])) for resource in resources)
    @test affected_resources(
        RESOURCES_ROOT,
        ["AIMORACases/examples/README.md"],
    ) == ["cases"]
    @test affected_resources(
        RESOURCES_ROOT,
        ["references/bpa_emtp/src/BPAEMTPReference.jl"],
    ) == ["bpa-emtp-reference"]
    @test length(affected_resources(RESOURCES_ROOT, ["licensing.toml"])) == 11

    for (directory, expected) in RESOURCE_PROJECTS
        project = TOML.parsefile(joinpath(
            RESOURCES_ROOT,
            directory,
            "Project.toml",
        ))
        @test project["name"] == expected.name
        @test project["uuid"] == expected.uuid
        @test project["version"] == expected.version
        @test project["license"] == "PolyForm-Noncommercial-1.0.0"
    end

    bpa_project = TOML.parsefile(joinpath(
        RESOURCES_ROOT,
        "references",
        "bpa_emtp",
        "Project.toml",
    ))
    @test bpa_project["uuid"] == "379ef2ed-aa07-4523-9a5b-6fc193417d96"
    @test bpa_project["version"] == "0.1.0"
end

@testset "AIMORA Resources licence and provenance contract" begin
    licensing = TOML.parsefile(joinpath(RESOURCES_ROOT, "licensing.toml"))
    @test licensing["schema"] == "aimora-resource-licensing-v1"
    @test licensing["root_license_does_not_override_path_specific_terms"]
    scopes = licensing["scope"]
    @test Set(scope["path"] for scope in scopes) == Set((
        ".",
        "AIMORACases",
        "AIMORACatalogs",
        "AIMORAReferenceModels",
        "references/bpa_emtp",
        "references/packages.toml",
        "references/review_library",
        "report-templates",
        "docs",
    ))
    @test all(isfile(joinpath(RESOURCES_ROOT, scope["license_file"])) for scope in scopes)
    bpa_scope = only(filter(scope -> scope["path"] == "references/bpa_emtp", scopes))
    @test isfile(joinpath(RESOURCES_ROOT, bpa_scope["notice"]))

    root_license_hash = bytes2hex(open(sha256, joinpath(
        RESOURCES_ROOT,
        "LICENSES",
        "PolyForm-Noncommercial-1.0.0.md",
    )))
    for relative_path in (
        "AIMORACases/LICENSE",
        "AIMORACatalogs/LICENSE",
        "AIMORAReferenceModels/LICENSE",
        "references/bpa_emtp/LICENSE",
        "report-templates/LICENSE",
        "docs/LICENSE",
    )
        @test bytes2hex(open(sha256, joinpath(RESOURCES_ROOT, relative_path))) ==
              root_license_hash
    end

    history = TOML.parsefile(joinpath(
        RESOURCES_ROOT,
        "provenance",
        "history-map.toml",
    ))
    @test history["schema"] == "aimora-resources-history-map-v1"
    @test length(history["source"]) == 6
    if success(`git -C $RESOURCES_ROOT rev-parse --verify HEAD`)
        for source in history["source"]
            @test success(`git -C $RESOURCES_ROOT merge-base --is-ancestor $(source["commit"]) HEAD`)
            @test isdir(joinpath(RESOURCES_ROOT, source["target"]))
        end
    end
end

@testset "AIMORA Resources artifact and privacy contract" begin
    policy = TOML.parsefile(joinpath(RESOURCES_ROOT, "artifact-policy.toml"))
    @test policy["schema"] == "aimora-resource-artifact-policy-v1"
    @test policy["classification_precedes_removal"]
    @test policy["baseline"]["tracked_csv"] == 139
    @test policy["baseline"]["tracked_svg"] == 123
    @test policy["baseline"]["tracked_pdf"] == 0
    @test policy["baseline"]["tracked_aimora_snapshot"] == 2
    @test policy["baseline"]["individually_classified"]
    @test policy["baseline"]["inventory"] == "baseline-artifacts.toml"
    @test Set(classification["state"] for classification in policy["classification"]) ==
          Set(("retained", "external"))

    inventory_path = joinpath(RESOURCES_ROOT, policy["baseline"]["inventory"])
    @test verify_inventory(inventory_path)
    inventory = TOML.parsefile(inventory_path)
    @test inventory["schema"] == "aimora-resource-artifact-baseline-v1"
    @test inventory["source_commit"] == policy["baseline"]["cases_commit"]
    inventory_artifacts = inventory["artifact"]
    @test length(inventory_artifacts) == 264
    @test length(Set(artifact["path"] for artifact in inventory_artifacts)) ==
          length(inventory_artifacts)
    @test Set(artifact["classification"] for artifact in inventory_artifacts) <= Set((
        "canonical-input",
        "immutable-reference",
        "curated-public-output",
        "reproducible-generated-output",
        "external-artifact",
    ))
    @test all(artifact["state"] == "retained" for artifact in inventory_artifacts)

    baseline_commit = policy["baseline"]["cases_commit"]
    baseline_paths = tree_paths(baseline_commit)
    baseline_csv_paths = filter(path -> endswith(lowercase(path), ".csv"), baseline_paths)
    baseline_svg_paths = filter(path -> endswith(lowercase(path), ".svg"), baseline_paths)
    baseline_pdf_paths = filter(path -> endswith(lowercase(path), ".pdf"), baseline_paths)
    baseline_snapshot_paths = filter(
        path -> any(
            suffix -> endswith(lowercase(path), suffix),
            (".aimora", ".aimora-snapshot"),
        ),
        baseline_paths,
    )
    @test length(baseline_csv_paths) == policy["baseline"]["tracked_csv"]
    @test length(baseline_svg_paths) == policy["baseline"]["tracked_svg"]
    @test length(baseline_pdf_paths) == policy["baseline"]["tracked_pdf"]
    @test length(baseline_snapshot_paths) ==
        policy["baseline"]["tracked_aimora_snapshot"]

    paths = tracked_paths()
    csv_paths = filter(path -> endswith(lowercase(path), ".csv"), paths)
    svg_paths = filter(path -> endswith(lowercase(path), ".svg"), paths)
    pdf_paths = filter(path -> endswith(lowercase(path), ".pdf"), paths)
    snapshot_paths = filter(
        path -> any(
            suffix -> endswith(lowercase(path), suffix),
            (".aimora", ".aimora-snapshot"),
        ),
        paths,
    )
    @test isempty(pdf_paths)
    @test all(startswith(path, "AIMORACases/examples/") for path in csv_paths)
    @test all(startswith(path, "AIMORACases/examples/") for path in svg_paths)
    @test all(
        startswith(path, "AIMORACases/examples/") for path in snapshot_paths
    )

    prefixed_baseline = Set(
        replace(String(artifact["path"]), "AIMORACases.jl/" => "AIMORACases/"; count = 1)
        for artifact in inventory_artifacts
    )
    current_artifacts = Set(vcat(csv_paths, svg_paths, snapshot_paths))
    added_artifacts = setdiff(current_artifacts, prefixed_baseline)
    retained_explicit_artifacts = Set(
        String(classification["path"]) for classification in policy["classification"]
        if haskey(classification, "path") && classification["state"] == "retained"
    )
    external_explicit_artifacts = Set(
        String(classification["path"]) for classification in policy["classification"]
        if haskey(classification, "path") && classification["state"] == "external"
    )
    @test added_artifacts == retained_explicit_artifacts
    @test isempty(intersect(current_artifacts, external_explicit_artifacts))
    @test all(
        classification["state"] in ("retained", "external") for
        classification in policy["classification"] if haskey(classification, "path")
    )
    @test !isfile(joinpath(RESOURCES_ROOT, ".gitmodules"))

    public_metadata = join((
        read(joinpath(RESOURCES_ROOT, "README.md"), String),
        read(joinpath(RESOURCES_ROOT, "resource-index.toml"), String),
        read(joinpath(RESOURCES_ROOT, "licensing.toml"), String),
    ), '\n')
    @test !occursin("AIMORASolvers", public_metadata)
    @test !occursin("private repository", lowercase(public_metadata))
end
