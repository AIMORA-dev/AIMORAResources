const PUBLIC_CUBIC_CURRENT_IDENTITY = _public_example_identity(
    "passive_cubic_current_branch",
    :PublicCubicCurrentBranch,
    "v=vp-vn;i=g*v+k*v^3;d=g+3*k*v^2",
)

struct PublicCubicCurrentBranch <: AIMORA.NativeExtensions.AbstractExtensionNonlinearDevice
    positive_node::Int
    negative_node::Int
    linear_conductance_s::Float64
    cubic_coefficient_a_per_v3::Float64
    provenance::AIMORA.StudyCore.ParameterProvenance

    function PublicCubicCurrentBranch(
        positive_node::Integer,
        negative_node::Integer,
        linear_conductance_s::Real,
        cubic_coefficient_a_per_v3::Real,
    )
        positive = Int(positive_node)
        negative = Int(negative_node)
        positive >= 0 && negative >= 0 && positive != negative || throw(ArgumentError(
            "public cubic branch terminals must be distinct nonnegative nodes",
        ))
        conductance = Float64(linear_conductance_s)
        cubic = Float64(cubic_coefficient_a_per_v3)
        all(isfinite, (conductance, cubic)) && conductance >= 0.0 && cubic >= 0.0 &&
            (conductance > 0.0 || cubic > 0.0) || throw(ArgumentError(
                "public cubic coefficients must be finite, nonnegative, and not both zero",
            ))
        return new(
            positive,
            negative,
            conductance,
            cubic,
            _public_parameter_provenance(
                "AIMORA public passive cubic-current example",
                "siemens and ampere per volt cubed",
                "two distinct nodes with g>=0 and k>=0, not both zero",
            ),
        )
    end
end

extension_identity(::Type{PublicCubicCurrentBranch}) = PUBLIC_CUBIC_CURRENT_IDENTITY
extension_contract(::Type{PublicCubicCurrentBranch}) = AIMORA.NativeExtensions.ExtensionContract(
    PUBLIC_CUBIC_CURRENT_IDENTITY,
    :nonlinear_electrical,
    :instantaneous_emt,
    :switching_detailed,
    2,
    (:initialize, :nonlinear_current, :jacobian, :output, :checkpoint),
    _public_example_inventory(Dict(
        :algebraic => (:terminal_voltage, :terminal_current),
        :output => (:terminal_current, :absorbed_power),
        :checkpoint => (:identity_only,),
    )),
    "passive two-terminal branch with finite g>=0 and k>=0, not both zero",
    unsupported = (:active_power_generation, :hidden_state, :topology_change),
)

nonlinear_terminal_nodes(device::PublicCubicCurrentBranch) =
    (device.positive_node, device.negative_node)
nonlinear_device_formulation(::PublicCubicCurrentBranch) =
    AIMORA.NonlinearNetwork.PhysicalConstitutiveCurrent
nonlinear_device_provenance(device::PublicCubicCurrentBranch) = device.provenance

function nonlinear_current_jacobian!(
    terminal_current_a::AbstractVector{Float64},
    terminal_jacobian_s::AbstractMatrix{Float64},
    device::PublicCubicCurrentBranch,
    terminal_voltage_v::AbstractVector{Float64},
    time_s::Float64,
)
    length(terminal_current_a) >= 2 && length(terminal_voltage_v) >= 2 ||
        throw(DimensionMismatch("public cubic branch requires two terminal values"))
    size(terminal_jacobian_s, 1) >= 2 && size(terminal_jacobian_s, 2) >= 2 ||
        throw(DimensionMismatch("public cubic branch requires a 2x2 Jacobian"))
    isfinite(time_s) || throw(ArgumentError("public cubic evaluation time must be finite"))
    voltage = terminal_voltage_v[1] - terminal_voltage_v[2]
    current = device.linear_conductance_s * voltage +
        device.cubic_coefficient_a_per_v3 * voltage^3
    derivative = device.linear_conductance_s +
        3.0 * device.cubic_coefficient_a_per_v3 * voltage^2
    terminal_current_a[1] = current
    terminal_current_a[2] = -current
    terminal_jacobian_s[1, 1] = derivative
    terminal_jacobian_s[1, 2] = -derivative
    terminal_jacobian_s[2, 1] = -derivative
    terminal_jacobian_s[2, 2] = derivative
    return nothing
end

extension_checkpoint(device::PublicCubicCurrentBranch) =
    AIMORA.NativeExtensions.ExtensionComponentCheckpoint(
        PUBLIC_CUBIC_CURRENT_IDENTITY,
        (stateless = true,),
        AIMORA.NativeExtensions.extension_state_signature((stateless = true,)),
    )

function restore_extension_checkpoint!(
    device::PublicCubicCurrentBranch,
    checkpoint::AIMORA.NativeExtensions.ExtensionComponentCheckpoint,
)
    checkpoint.identity == PUBLIC_CUBIC_CURRENT_IDENTITY && checkpoint.state == (stateless = true,) &&
        checkpoint.state_sha256 == AIMORA.NativeExtensions.extension_state_signature(checkpoint.state) ||
        throw(AIMORA.NativeExtensions.ExtensionFailure(
            :incompatible_extension_checkpoint,
            :restore_checkpoint,
            PUBLIC_CUBIC_CURRENT_IDENTITY,
            "public cubic checkpoint is incompatible",
        ))
    return device
end

function extension_outputs(
    device::PublicCubicCurrentBranch,
    terminal_voltage_v::AbstractVector{<:Real},
    time_s::Real,
)
    length(terminal_voltage_v) >= 2 || throw(DimensionMismatch(
        "public cubic output requires two terminal voltages",
    ))
    voltage = Float64(terminal_voltage_v[1] - terminal_voltage_v[2])
    current = device.linear_conductance_s * voltage +
        device.cubic_coefficient_a_per_v3 * voltage^3
    return (
        AIMORA.NativeExtensions.ExtensionOutputValue(
            :terminal_current,
            current,
            "A",
            time_s,
            :valid,
            PUBLIC_CUBIC_CURRENT_IDENTITY,
        ),
        AIMORA.NativeExtensions.ExtensionOutputValue(
            :absorbed_power,
            voltage * current,
            "W",
            time_s,
            :valid,
            PUBLIC_CUBIC_CURRENT_IDENTITY,
        ),
    )
end
