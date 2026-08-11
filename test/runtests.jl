using SHA
using Test
using TOML

const RESOURCES_ROOT = normpath(joinpath(@__DIR__, ".."))
include(joinpath(RESOURCES_ROOT, "tools", "changed_resources.jl"))
using .ChangedResources

const RESOURCE_PROJECTS = Dict(
    "AIMORACases.jl" => (
        name = "AIMORACases",
        uuid = "c2d99356-2241-4b88-ae11-80a94b927354",
        version = "0.1.0",
    ),
    "AIMORACatalogs.jl" => (
        name = "AIMORACatalogs",
        uuid = "2b6c9f6e-dc5c-4462-b175-cd3ce62f4f80",
        version = "0.1.0",
    ),
    "AIMORAReferenceModels.jl" => (
        name = "AIMORAReferenceModels",
        uuid = "6a268073-c1b2-474c-bd10-49e12d1609a5",
        version = "0.1.0",
    ),
)

function tracked_paths()
    output = read(`git -C $RESOURCES_ROOT ls-files -z`, String)
    return filter(!isempty, split(output, '\0'))
end

@testset "AIMORA Resources repository contract" begin
    for relative_path in (
        "licensing.toml",
        "resource-index.toml",
        "artifact-policy.toml",
        "provenance/history-map.toml",
        "AIMORACases.jl",
        "AIMORACatalogs.jl",
        "AIMORAReferenceModels.jl",
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
        ["AIMORACases.jl/examples/README.md"],
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
        "AIMORACases.jl",
        "AIMORACatalogs.jl",
        "AIMORAReferenceModels.jl",
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
        "AIMORACases.jl/LICENSE",
        "AIMORACatalogs.jl/LICENSE",
        "AIMORAReferenceModels.jl/LICENSE",
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
    @test policy["baseline"]["tracked_csv"] == 130
    @test policy["baseline"]["tracked_svg"] == 108
    @test policy["baseline"]["tracked_pdf"] == 0
    @test Set(classification["state"] for classification in policy["classification"]) ==
          Set(("retained", "external"))

    paths = tracked_paths()
    csv_paths = filter(path -> endswith(lowercase(path), ".csv"), paths)
    svg_paths = filter(path -> endswith(lowercase(path), ".svg"), paths)
    pdf_paths = filter(path -> endswith(lowercase(path), ".pdf"), paths)
    @test length(csv_paths) == 130
    @test length(svg_paths) == 108
    @test isempty(pdf_paths)
    @test all(startswith(path, "AIMORACases.jl/examples/") for path in csv_paths)
    @test all(startswith(path, "AIMORACases.jl/examples/") for path in svg_paths)
    @test !isfile(joinpath(RESOURCES_ROOT, ".gitmodules"))

    public_metadata = join((
        read(joinpath(RESOURCES_ROOT, "README.md"), String),
        read(joinpath(RESOURCES_ROOT, "resource-index.toml"), String),
        read(joinpath(RESOURCES_ROOT, "licensing.toml"), String),
    ), '\n')
    @test !occursin("AIMORASolvers", public_metadata)
    @test !occursin("private repository", lowercase(public_metadata))
end
