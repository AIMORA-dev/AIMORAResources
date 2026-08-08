using Test
using AIMORAReferenceModels

@testset "independent reference-model package boundary" begin
    @test nameof(AIMORAReferenceModels) === :AIMORAReferenceModels
end
