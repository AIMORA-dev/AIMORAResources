using Test
using LinearAlgebra
using AIMORAReferenceModels

@testset "Independent coupled fitting and passivity formulations" begin
    frequencies_hz = exp10.(range(0.0, 4.0; length=33))
    poles_per_s = ComplexF64[-20.0 + 100.0im, -20.0 - 100.0im]
    residue = ComplexF64[
        0.8 + 0.2im 0.1 + 0.05im
        0.1 + 0.05im 0.6 + 0.1im
    ]
    residues = [residue, conj.(residue)]
    direct = [0.05 0.01; 0.01 0.04]
    responses = independent_coupled_rational_response(
        frequencies_hz,
        direct,
        poles_per_s,
        residues,
    )
    @test length(responses) == length(frequencies_hz)
    @test all(matrix -> matrix ≈ transpose(matrix), responses)
    @test independent_coupled_continuous_gain_bound(
        direct,
        poles_per_s,
        residues,
    ) < 1.0

    admittance = ComplexF64[0.02 0.002; 0.002 0.03]
    reference = [50.0, 50.0]
    scattering = independent_coupled_admittance_to_scattering(admittance, reference)
    @test independent_coupled_scattering_to_admittance(scattering, reference) ≈
        admittance atol=1.0e-14

    basis = ComplexF64[1.0 0.0; 0.0 1.0; 0.0 0.0]
    rotated = basis * ComplexF64[0.0 1.0; -1.0 0.0]
    @test maximum(independent_coupled_principal_angles(basis, rotated)) <= 2.0e-8

    times_s = collect(range(0.0, 0.01; length=101))
    incident = [[sin(2.0 * pi * 100.0 * time), 0.5cos(2.0 * pi * 70.0 * time)]
        for time in times_s]
    reflected = [0.5 .* wave for wave in incident]
    energy = independent_coupled_wave_energy(times_s, incident, reflected)
    @test minimum(energy.cumulative_energy_j) >= -eps(Float64)
    @test last(energy.cumulative_energy_j) > 0.0
end
