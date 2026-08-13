using Test
using LinearAlgebra
using AIMORAReferenceModels

@testset "Independent wideband line-parameter references" begin
    potential = independent_line_potential_coefficients(
        [-3.0, 0.0, 3.0],
        fill(10.0, 3),
        fill(0.01, 3),
    )
    @test potential == transpose(potential)
    @test eigmin(Symmetric(potential)) > 0.0

    matrix = ComplexF64[
        4.0 + 2.0im 1.0im 0.5im
        1.0im 3.0 + 2.0im 0.25im
        0.5im 0.25im 2.0 + 1.0im
    ]
    expected = matrix[1:2, 1:2] -
        matrix[1:2, 3:3] * (matrix[3:3, 3:3] \ matrix[3:3, 1:2])
    @test independent_line_kron_reduction(matrix, 1:2, [3]) ≈ expected

    first_matrix = ComplexF64[2.0 0.5; 0.5 3.0]
    second_matrix = ComplexF64[7.0 1.0; 1.0 5.0]
    @test independent_line_route_sum(
        [10.0, 20.0],
        [first_matrix, second_matrix],
        [[1, 2], [2, 1]],
    ) ≈ 10.0first_matrix + 20.0second_matrix[[2, 1], [2, 1]]

    radii = independent_line_uncertainty_envelope(
        [first_matrix],
        [[first_matrix .+ 0.2], [first_matrix .- 0.1]],
    )
    @test only(radii) ≈ fill(0.2, 2, 2)

    admittance = independent_coaxial_cable_admittance(
        0.01,
        0.02,
        2.3,
        60.0,
    )
    @test real(admittance) == 0.0
    @test imag(admittance) > 0.0
end
