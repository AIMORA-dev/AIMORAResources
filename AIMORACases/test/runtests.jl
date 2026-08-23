using Test
using AIMORA
using AIMORACases
using AIMORAProject
using TOML
using UUIDs

include(joinpath(AIMORACases.package_root(), "examples", "Qualification.jl"))
using .AIMORAExampleQualification

@testset "case catalog" begin
    cases = AIMORACases.available_cases()
    catalog = TOML.parsefile(
        joinpath(AIMORACases.package_root(), "examples", "catalog.toml"),
    )
    @test catalog["schema"] == "aimora-examples-v2"
    @test length(cases) == length(catalog["case"])
    @test length(unique(case.id for case in cases)) == length(cases)
    @test all(case -> isfile(AIMORACases.case_path(case.id)), cases)
    @test all(case -> !isempty(strip(case.description)), cases)
    @test all(
        row -> isfile(joinpath(AIMORACases.package_root(), row["entrypoint"])),
        catalog["case"],
    )
    @test AIMORACases.case_descriptor(:emt_rlc_energization).study == :emt
    @test_throws KeyError AIMORACases.case_descriptor(:missing)
end

@testset "external native extension registry and inert project binding" begin
    registry = native_extension_registry()
    @test length(AIMORA.NativeExtensions.registered_extension_identities(registry)) == 3
    source_control = PublicSampledSaturatingLag(1.0, 1.0e-3, -1.0, 1.0, 10)
    AIMORA.NativeExtensions.sample_extension_task!(source_control, 0.5, 0, 1.0e-4)
    @test AIMORA.NativeExtensions.extension_source_value(source_control, 0.0) > 0.0
    licence = LicenceIdentity(
        "PolyForm-Noncommercial-1.0.0",
        "PolyForm Noncommercial 1.0.0",
    )
    provenance = ProvenanceSource(
        ProjectId("source.public_extension_example"),
        "AIMORA synthetic public native-extension example",
        licence;
        source_version = "1.0.0",
    )
    declaration = native_extension_declaration(
        PublicCubicCurrentBranch,
        ObjectIdentity(ProjectId("device.public_cubic")),
        [
            ProjectReference(ReferenceNode, ProjectId("node.positive")),
            ProjectReference(ReferenceNode, ProjectId("node.negative")),
        ],
        [
            AssetProperty(
                FieldPath("cubic.linear_conductance_s"),
                parse_exact_decimal("0.2"),
                provenance,
            ),
        ],
        provenance,
    )
    registration = AIMORA.NativeExtensions.resolve_extension(registry, declaration)
    @test registration.implementation_type === PublicCubicCurrentBranch
    @test declaration.implementation.package_uuid ==
        UUID("c2d99356-2241-4b88-ae11-80a94b927354")
    @test length(declaration.state) == 9
    @test extension_declaration_hash(declaration) == extension_declaration_hash(declaration)
    @test occursin(r"^[0-9a-f]{64}$", string(extension_declaration_hash(declaration)))
    @test_throws ArgumentError native_extension_declaration(
        PublicCubicCurrentBranch,
        ObjectIdentity(ProjectId("device.invalid_terminal_count")),
        [ProjectReference(ReferenceNode, ProjectId("node.only"))],
        AssetProperty[],
        provenance,
    )
end

@testset "impact-selected example qualification" begin
    root = AIMORACases.package_root()
    targets = example_targets(root)
    selected = select_changed_targets(
        targets,
        [
            "examples/emt/rlc_energization/run.jl",
            "examples/line_constants/double_circuit/outputs/sequence_impedance.csv",
        ],
    )
    @test getfield.(selected, :id) == ["emt_rlc_energization", "line_constants_double_circuit"]
    @test only(select_targets(targets, ["transformer_parameters_two_winding_short_circuit"])).directory ==
          "examples/transformer_parameters/two_winding_short_circuit"
    @test isempty(select_changed_targets(targets, ["examples/support/ExampleSupport.jl"]))
    @test_throws ErrorException select_targets(targets, ["missing_example"])
    @test_throws ErrorException run_examples(root, selected; plan_only = true, worker_count = 6)
end

@testset "release receipts and artifact identity" begin
    @test AIMORAExampleQualification._git_content_signature(
        joinpath(@__DIR__, "missing-private-solver"),
    ) == "unavailable"

    mktempdir() do directory
        target = ExampleTarget("receipt_test", "example", "example/run.jl")
        signature = "abc123"
        path = AIMORAExampleQualification._write_receipt(
            directory,
            target,
            signature,
            1.0,
        )
        @test receipt_is_valid(path, signature)
        @test receipt_is_valid(path, signature, target.id)
        @test !receipt_is_valid(path, signature, "different_example")
        write(path, replace(read(path, String), "passed" => "failed"))
        @test !receipt_is_valid(path, signature)

        committed = joinpath(directory, target.directory, "outputs")
        generated = joinpath(directory, "generated")
        mkpath(committed)
        mkpath(generated)
        write(joinpath(committed, "result.csv"), "x\n1\n")
        write(joinpath(generated, "result.csv"), "x\n1\n")
        @test AIMORAExampleQualification._assert_exact_artifacts(
            directory,
            target,
            generated,
        )
        write(joinpath(generated, "result.csv"), "x\n2\n")
        @test_throws ErrorException AIMORAExampleQualification._assert_exact_artifacts(
            directory,
            target,
            generated,
        )

        manifest_target = ExampleTarget(
            "emt_parsed_deck_trace",
            "manifest_example",
            "manifest_example/run.jl",
        )
        manifest_outputs = joinpath(directory, manifest_target.directory, "outputs")
        manifest_generated = joinpath(directory, "manifest_generated")
        mkpath(manifest_outputs)
        mkpath(manifest_generated)
        write(
            joinpath(manifest_outputs, "report_manifest.json"),
            "{\"path\":\"outputs/report.csv\"}\n",
        )
        write(
            joinpath(manifest_generated, "report_manifest.json"),
            "{\"path\":\"$(abspath(manifest_generated))/report.csv\"}\n",
        )
        @test AIMORAExampleQualification._assert_exact_artifacts(
            directory,
            manifest_target,
            manifest_generated,
        )

        realtime_target = ExampleTarget(
            "emt_realtime_cpu",
            "realtime_example",
            "realtime_example/run.jl",
        )
        realtime_outputs = joinpath(directory, realtime_target.directory, "outputs")
        realtime_generated = joinpath(directory, "realtime_generated")
        mkpath(realtime_outputs)
        mkpath(realtime_generated)
        stable_realtime = """{
  \"engine\": \"CPU\",
  \"steps\": 10,
  \"dt_s\": 0.000020000,
  \"duration_s\": 0.000200000,
  \"mean_step_s\": MEAN_STEP,
  \"max_step_s\": MAX_STEP,
  \"overruns\": 0,
  \"realtime\": false
}
"""
        write(
            joinpath(realtime_outputs, "realtime_summary.json"),
            replace(
                stable_realtime,
                "MEAN_STEP" => "0.000001000",
                "MAX_STEP" => "0.000003000",
            ),
        )
        write(
            joinpath(realtime_generated, "realtime_summary.json"),
            replace(
                stable_realtime,
                "MEAN_STEP" => "0.000002000",
                "MAX_STEP" => "0.000004000",
            ),
        )
        @test AIMORAExampleQualification._assert_exact_artifacts(
            directory,
            realtime_target,
            realtime_generated,
        )
    end
end

@testset "source coverage contract" begin
    root = AIMORACases.package_root()
    catalog = TOML.parsefile(joinpath(root, "examples", "catalog.toml"))
    coverage = TOML.parsefile(joinpath(root, "examples", "source_coverage.toml"))
    rows = coverage["source"]
    ids = Set(String(row["id"]) for row in rows)
    example_ids = Set(String(row["id"]) for row in catalog["case"])

    @test coverage["schema"] == "aimora-source-coverage-v1"
    @test coverage["source_count"] == length(rows)
    @test length(ids) == length(rows)
    @test all(
        row -> all(in(example_ids), String.(row["example_ids"])),
        rows,
    )
    @test all(
        row -> all(in(ids), String.(get(row, "source_ids", String[]))),
        catalog["case"],
    )
end
