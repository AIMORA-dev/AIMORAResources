using Test
using BPAEMTPReference

@testset "reference package layout" begin
    @test isdir(BPAEMTPReference.source_dir())
    @test isfile(joinpath(BPAEMTPReference.source_dir(), "MAIN00.FOR"))
    @test isfile(joinpath(BPAEMTPReference.source_dir(), "OVER16.FOR"))
end

@testset "report classification" begin
    @test BPAEMTPReference.report_status("Fortran runtime error", 1) == :runtime_error
    @test BPAEMTPReference.report_status("DATA CRISIS", 0) == :deck_data_error
    @test BPAEMTPReference.report_status("EMTP BEGINS", 0) == :completed
    @test BPAEMTPReference.report_status("unrecognized", 2) == :process_failed
end

if isfile(BPAEMTPReference.executable_path())
    @testset "compiled reference example" begin
        deck = read(
            joinpath(
                @__DIR__,
                "..",
                "examples",
                "emt",
                "rlc_energization",
                "rlc_energization.deck",
            ),
            String,
        )
        result = BPAEMTPReference.run_deck(
            deck;
            output_dir = mktempdir(),
            timeout_s = 30.0,
        )
        @test result.process_ok
        @test !result.error_detected
        @test result.status in (:completed, :clean_stop)
    end
end
