export independent_line_potential_coefficients,
       independent_line_kron_reduction,
       independent_line_route_sum,
       independent_line_uncertainty_envelope,
       independent_coaxial_cable_admittance

"""Independently assemble flat-earth overhead potential coefficients in volt metre per coulomb."""
function independent_line_potential_coefficients(
    horizontal_position_m,
    height_m,
    radius_m;
    permittivity_f_per_m::Real=8.8541878128e-12,
)
    horizontal = Float64.(horizontal_position_m)
    height = Float64.(height_m)
    radius = Float64.(radius_m)
    length(horizontal) == length(height) == length(radius) ||
        throw(DimensionMismatch("independent line geometry vectors must have equal length"))
    count = length(horizontal)
    count > 0 || throw(ArgumentError("independent line geometry must not be empty"))
    epsilon = Float64(permittivity_f_per_m)
    isfinite(epsilon) && epsilon > 0.0 ||
        throw(ArgumentError("independent line permittivity must be positive"))
    result = Matrix{Float64}(undef, count, count)
    scale = inv(2.0 * pi * epsilon)
    for column in 1:count, row in 1:column
        height[row] > radius[row] > 0.0 || throw(ArgumentError(
            "independent overhead conductor height must exceed positive radius",
        ))
        value = if row == column
            scale * log(2.0 * height[row] / radius[row])
        else
            direct = hypot(
                horizontal[row] - horizontal[column],
                height[row] - height[column],
            )
            image = hypot(
                horizontal[row] - horizontal[column],
                height[row] + height[column],
            )
            direct > 0.0 || throw(ArgumentError(
                "independent overhead conductors cannot share coordinates",
            ))
            scale * log(image / direct)
        end
        result[row, column] = value
        result[column, row] = value
    end
    return result
end

"""Independently eliminate explicitly grounded conductors by a Schur complement."""
function independent_line_kron_reduction(matrix, active_indices, grounded_indices)
    values = Matrix{ComplexF64}(matrix)
    size(values, 1) == size(values, 2) ||
        throw(DimensionMismatch("independent line matrix must be square"))
    active = collect(Int.(active_indices))
    grounded = collect(Int.(grounded_indices))
    isempty(active) && throw(ArgumentError("independent reduction requires active conductors"))
    isempty(grounded) && return values[active, active]
    return values[active, active] -
        values[active, grounded] *
        (values[grounded, grounded] \ values[grounded, active])
end

"""Independently map and sum per-length route matrices without forming a propagation model."""
function independent_line_route_sum(length_m, matrices, permutations)
    length(length_m) == length(matrices) == length(permutations) ||
        throw(DimensionMismatch("independent route rows must have equal length"))
    isempty(length_m) && throw(ArgumentError("independent route requires segments"))
    width = size(first(matrices), 1)
    result = zeros(ComplexF64, width, width)
    for index in eachindex(length_m)
        length_value = Float64(length_m[index])
        isfinite(length_value) && length_value > 0.0 ||
            throw(ArgumentError("independent route length must be positive"))
        order = collect(Int.(permutations[index]))
        sort(order) == collect(1:width) || throw(ArgumentError(
            "independent route mapping must be a permutation",
        ))
        result .+= length_value .* Matrix{ComplexF64}(matrices[index])[order, order]
    end
    return result
end

"""Independently form componentwise deterministic uncertainty radii around a nominal matrix set."""
function independent_line_uncertainty_envelope(nominal, alternatives)
    nominal_rows = [Matrix{ComplexF64}(matrix) for matrix in nominal]
    radii = [zeros(Float64, size(matrix)) for matrix in nominal_rows]
    for alternative in alternatives
        length(alternative) == length(nominal_rows) ||
            throw(DimensionMismatch("independent uncertainty grids must match"))
        for index in eachindex(nominal_rows)
            radii[index] .= max.(
                radii[index],
                abs.(Matrix{ComplexF64}(alternative[index]) - nominal_rows[index]),
            )
        end
    end
    return radii
end

"""Return exact per-length shunt admittance of one ideal coaxial dielectric layer."""
function independent_coaxial_cable_admittance(
    inner_radius_m::Real,
    outer_radius_m::Real,
    relative_permittivity::Real,
    frequency_hz::Real;
    loss_tangent::Real=0.0,
)
    inner = Float64(inner_radius_m)
    outer = Float64(outer_radius_m)
    permittivity = Float64(relative_permittivity)
    frequency = Float64(frequency_hz)
    loss = Float64(loss_tangent)
    0.0 < inner < outer || throw(ArgumentError(
        "independent coaxial radii must be positive and nested",
    ))
    isfinite(permittivity) && permittivity > 0.0 ||
        throw(ArgumentError("independent relative permittivity must be positive"))
    isfinite(frequency) && frequency > 0.0 ||
        throw(ArgumentError("independent frequency must be positive"))
    isfinite(loss) && loss >= 0.0 ||
        throw(ArgumentError("independent loss tangent must be nonnegative"))
    capacitance = 2.0 * pi * 8.8541878128e-12 * permittivity /
        log(outer / inner)
    angular_frequency = 2.0 * pi * frequency
    return ComplexF64(
        angular_frequency * capacitance * loss,
        angular_frequency * capacitance,
    )
end
