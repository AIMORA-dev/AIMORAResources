using Test
using AIMORACases

@testset "case catalog" begin
    cases = AIMORACases.available_cases()
    @test length(cases) == 5
    @test length(unique(case.id for case in cases)) == length(cases)
    @test all(case -> isfile(AIMORACases.case_path(case.id)), cases)
    @test all(case -> !isempty(strip(case.description)), cases)
    @test AIMORACases.case_descriptor(:emt_rlc_energization).study == :emt
    @test_throws KeyError AIMORACases.case_descriptor(:missing)
end
