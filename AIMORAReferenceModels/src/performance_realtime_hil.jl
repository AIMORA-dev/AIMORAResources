function independent_scaled_linear_residual(
    admittance::AbstractMatrix{<:Real},
    voltage::AbstractVector{<:Real},
    current::AbstractVector{<:Real};
    scale_guard::Real=eps(Float64),
)
    size(admittance, 1) == size(admittance, 2) || throw(DimensionMismatch(
        "independent admittance matrix must be square",
    ))
    size(admittance, 2) == length(voltage) == length(current) ||
        throw(DimensionMismatch("independent nodal dimensions must agree"))
    matrix = Matrix{Float64}(admittance)
    solution = Vector{Float64}(voltage)
    right_hand_side = Vector{Float64}(current)
    all(isfinite, matrix) && all(isfinite, solution) &&
        all(isfinite, right_hand_side) || throw(ArgumentError(
            "independent nodal values must be finite",
        ))
    guard = Float64(scale_guard)
    isfinite(guard) && guard > 0.0 || throw(ArgumentError(
        "independent residual scale guard must be finite and positive",
    ))
    residual = matrix * solution - right_hand_side
    denominator = opnorm(matrix) * norm(solution) + norm(right_hand_side) + guard
    return (
        residual=residual,
        scaled_norm=norm(residual) / denominator,
    )
end

function independent_indexed_collection(
    indexed_results::AbstractVector,
    expected_count::Integer,
)
    count = Int(expected_count)
    count >= 0 || throw(ArgumentError(
        "independent expected result count must be nonnegative",
    ))
    staged = Vector{Any}(undef, count)
    seen = falses(count)
    for result in indexed_results
        index = Int(result.index)
        1 <= index <= count || throw(BoundsError(staged, index))
        seen[index] && throw(ArgumentError(
            "independent indexed collection received a duplicate result",
        ))
        staged[index] = result.value
        seen[index] = true
    end
    all(seen) || throw(ArgumentError(
        "independent indexed collection omitted a result",
    ))
    return staged
end

function independent_realtime_release_ns(
    epoch_ns::Integer,
    period_ns::Integer,
    step::Integer,
)
    period_ns > 0 || throw(ArgumentError("independent period must be positive"))
    step >= 0 || throw(ArgumentError("independent step must be nonnegative"))
    return Base.Checked.checked_add(
        Int64(epoch_ns),
        Base.Checked.checked_mul(Int64(period_ns), Int64(step)),
    )
end

function independent_realtime_metrics(
    release_ns::Integer,
    start_ns::Integer,
    completion_ns::Integer,
    period_ns::Integer,
)
    release = Int64(release_ns)
    start = Int64(start_ns)
    completion = Int64(completion_ns)
    period = Int64(period_ns)
    period > 0 || throw(ArgumentError("independent period must be positive"))
    release <= start <= completion || throw(ArgumentError(
        "independent monotonic timestamps must be causal",
    ))
    deadline = Base.Checked.checked_add(release, period)
    response = completion - release
    return (
        release_ns=release,
        deadline_ns=deadline,
        jitter_ns=start - release,
        computation_ns=completion - start,
        response_ns=response,
        slack_ns=deadline - completion,
        overrun=response > period,
    )
end

function independent_affine_channel_value(
    raw_value::Real,
    scale::Real,
    offset::Real,
)
    numeric = Float64.((raw_value, scale, offset))
    all(isfinite, numeric) || throw(ArgumentError(
        "independent affine channel values must be finite",
    ))
    numeric[2] != 0.0 || throw(ArgumentError(
        "independent affine channel scale must be nonzero",
    ))
    return muladd(numeric[2], numeric[1], numeric[3])
end

function independent_loopback_controller_step(
    state::Real,
    input::Real,
    response_fraction::Real,
    gain::Real,
)
    numeric = Float64.((state, input, response_fraction, gain))
    all(isfinite, numeric) || throw(ArgumentError(
        "independent controller values must be finite",
    ))
    0.0 <= numeric[3] <= 1.0 || throw(ArgumentError(
        "independent controller response_fraction must be in [0, 1]",
    ))
    next_state = numeric[1] + numeric[3] * (numeric[2] - numeric[1])
    return (state=next_state, output=numeric[4] * next_state)
end

function independent_realtime_replay_signature(frames::AbstractVector)
    signature_io = IOBuffer()
    println(signature_io, "aimora-independent-realtime-replay-v1")
    for frame in frames
        println(signature_io, frame.sequence)
        println(signature_io, frame.logical_time_ns)
        println(signature_io, join(repr.(frame.values), ','))
        println(signature_io, frame.valid)
    end
    return bytes2hex(sha256(take!(signature_io)))
end
