using Test
using AIMORACases
using TOML

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
