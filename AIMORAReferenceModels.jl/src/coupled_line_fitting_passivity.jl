export independent_coupled_rational_response,
       independent_coupled_admittance_to_scattering,
       independent_coupled_scattering_to_admittance,
       independent_coupled_principal_angles,
       independent_coupled_continuous_gain_bound,
       independent_coupled_wave_energy

function _independent_square_complex_matrix(values, label::AbstractString)
    matrix = Matrix{ComplexF64}(values)
    size(matrix, 1) == size(matrix, 2) && !isempty(matrix) ||
        throw(DimensionMismatch("$label must be a nonempty square matrix"))
    all(value -> isfinite(real(value)) && isfinite(imag(value)), matrix) ||
        throw(ArgumentError("$label must be finite"))
    return matrix
end

function _independent_reference_diagonal(values, dimension::Int)
    reference = Float64.(values)
    length(reference) == dimension && all(value -> isfinite(value) && value > 0.0, reference) ||
        throw(ArgumentError("independent wave reference must be positive and dimension-matched"))
    return reference
end

"""Evaluate a complete matrix rational response without using an AIMORA fit object."""
function independent_coupled_rational_response(
    frequencies_hz,
    direct_term,
    poles_per_s,
    residue_matrices_per_s,
)
    frequencies = Float64.(frequencies_hz)
    !isempty(frequencies) && all(value -> isfinite(value) && value >= 0.0, frequencies) ||
        throw(ArgumentError("independent rational frequencies must be finite and nonnegative"))
    direct = _independent_square_complex_matrix(direct_term, "independent direct term")
    poles = ComplexF64.(poles_per_s)
    residues = [
        _independent_square_complex_matrix(matrix, "independent residue")
        for matrix in residue_matrices_per_s
    ]
    length(poles) == length(residues) && !isempty(poles) || throw(DimensionMismatch(
        "independent pole and residue counts must be nonzero and equal",
    ))
    dimension = size(direct, 1)
    all(matrix -> size(matrix) == (dimension, dimension), residues) ||
        throw(DimensionMismatch("independent residues must share the direct-term dimension"))
    all(pole -> isfinite(real(pole)) && isfinite(imag(pole)) && real(pole) < 0.0, poles) ||
        throw(ArgumentError("independent rational poles must be stable and finite"))
    return [
        reduce(
            +,
            (
                residues[index] ./ (2.0im * pi * frequency - poles[index])
                for index in eachindex(poles)
            );
            init=copy(direct),
        ) for frequency in frequencies
    ]
end

"""Map inward-current terminal admittance to normalized power-wave scattering."""
function independent_coupled_admittance_to_scattering(
    terminal_admittance,
    reference_impedance_ohm,
)
    admittance = _independent_square_complex_matrix(
        terminal_admittance,
        "independent terminal admittance",
    )
    reference = _independent_reference_diagonal(
        reference_impedance_ohm,
        size(admittance, 1),
    )
    root = Diagonal(sqrt.(reference))
    normalized = root * admittance * root
    identity_matrix = Matrix{ComplexF64}(I, size(admittance)...)
    return (identity_matrix + normalized) \
        (identity_matrix - normalized)
end

"""Map normalized power-wave scattering to inward-current terminal admittance."""
function independent_coupled_scattering_to_admittance(
    scattering,
    reference_impedance_ohm,
)
    response = _independent_square_complex_matrix(scattering, "independent scattering")
    reference = _independent_reference_diagonal(reference_impedance_ohm, size(response, 1))
    identity_matrix = Matrix{ComplexF64}(I, size(response)...)
    normalized = (identity_matrix + response) \
        (identity_matrix - response)
    inverse_root = Diagonal(inv.(sqrt.(reference)))
    return inverse_root * normalized * inverse_root
end

"""Return principal angles between two independently supplied invariant subspaces."""
function independent_coupled_principal_angles(previous_basis, current_basis)
    previous = Matrix{ComplexF64}(previous_basis)
    current = Matrix{ComplexF64}(current_basis)
    size(previous, 1) == size(current, 1) && size(previous, 2) == size(current, 2) &&
        size(previous, 2) > 0 || throw(DimensionMismatch(
        "independent invariant subspaces must have equal nonzero dimensions",
    ))
    previous_orthogonal = Matrix(qr(previous).Q)[:, 1:size(previous, 2)]
    current_orthogonal = Matrix(qr(current).Q)[:, 1:size(current, 2)]
    cosines = clamp.(
        svdvals(adjoint(previous_orthogonal) * current_orthogonal),
        0.0,
        1.0,
    )
    return sort!(acos.(cosines))
end

"""
Return a rigorous all-frequency induced-gain upper bound.

For stable poles, `norm(R/(j*w-p)) <= norm(R)/(-real(p))`. The triangle
inequality therefore bounds the complete response for every real frequency.
This conservative certificate is independent of sampled passivity searches and
is intended for manufactured reference networks whose bound is below one.
"""
function independent_coupled_continuous_gain_bound(
    direct_term,
    poles_per_s,
    residue_matrices_per_s,
)
    direct = _independent_square_complex_matrix(direct_term, "independent direct term")
    poles = ComplexF64.(poles_per_s)
    length(poles) == length(residue_matrices_per_s) && !isempty(poles) ||
        throw(DimensionMismatch("independent pole and residue counts must be equal"))
    bound = opnorm(direct)
    for index in eachindex(poles)
        pole = poles[index]
        isfinite(real(pole)) && isfinite(imag(pole)) && real(pole) < 0.0 ||
            throw(ArgumentError("independent gain bound requires stable finite poles"))
        residue = _independent_square_complex_matrix(
            residue_matrices_per_s[index],
            "independent residue",
        )
        size(residue) == size(direct) || throw(DimensionMismatch(
            "independent gain-bound matrices must share dimensions",
        ))
        bound += opnorm(residue) / (-real(pole))
    end
    return bound
end

"""Integrate incident-minus-reflected wave power and return every energy prefix."""
function independent_coupled_wave_energy(times_s, incident_waves, reflected_waves)
    times = Float64.(times_s)
    length(times) == length(incident_waves) == length(reflected_waves) &&
        length(times) >= 2 || throw(DimensionMismatch(
        "independent wave energy rows must align and contain at least two times",
    ))
    issorted(times) && all(diff(times) .> 0.0) || throw(ArgumentError(
        "independent wave energy times must be strictly increasing",
    ))
    dimension = length(first(incident_waves))
    dimension > 0 || throw(ArgumentError("independent incident wave cannot be empty"))
    power = Float64[]
    for index in eachindex(times)
        incident = ComplexF64.(incident_waves[index])
        reflected = ComplexF64.(reflected_waves[index])
        length(incident) == length(reflected) == dimension || throw(DimensionMismatch(
            "independent incident and reflected wave dimensions must remain fixed",
        ))
        value = sum(abs2, incident) - sum(abs2, reflected)
        isfinite(value) || throw(ArgumentError("independent wave power must be finite"))
        push!(power, value)
    end
    energy = zeros(Float64, length(times))
    for index in 2:length(times)
        energy[index] = energy[index - 1] +
            0.5 * (power[index - 1] + power[index]) * (times[index] - times[index - 1])
    end
    return (instantaneous_power_w=power, cumulative_energy_j=energy)
end
