const PUBLIC_SAMPLED_LAG_IDENTITY = _public_example_identity(
    "sampled_saturating_lag",
    :PublicSampledSaturatingLag,
    "a=1-exp(-h/tau);x_next=x+a*(u-x);y=clamp(gain*x_next,y_min,y_max)",
)

mutable struct PublicSampledSaturatingLag <: AIMORA.NativeExtensions.AbstractExtensionControlBlock
    gain::Float64
    time_constant_s::Float64
    minimum_output::Float64
    maximum_output::Float64
    period_ticks::Int
    delay_ticks::Int
    state::Float64
    held_input::Float64
    held_output::Float64
    pending_output::Float64
    next_sample_tick::Int
    pending_release_tick::Int
    sample_count::Int
    write_count::Int
    provenance::AIMORA.StudyCore.ParameterProvenance

    function PublicSampledSaturatingLag(
        gain::Real,
        time_constant_s::Real,
        minimum_output::Real,
        maximum_output::Real,
        period_ticks::Integer;
        delay_ticks::Integer = 0,
        initial_state::Real = 0.0,
    )
        values = Float64.((gain, time_constant_s, minimum_output, maximum_output, initial_state))
        all(isfinite, values) || throw(ArgumentError("public sampled-lag values must be finite"))
        gain_value, time_constant, minimum, maximum, state = values
        time_constant > 0.0 || throw(ArgumentError("public sampled-lag time constant must be positive"))
        minimum <= maximum || throw(ArgumentError("public sampled-lag output bounds are reversed"))
        period = Int(period_ticks)
        delay = Int(delay_ticks)
        period > 0 || throw(ArgumentError("public sampled-lag period must be positive"))
        0 <= delay < period || throw(ArgumentError(
            "public sampled-lag delay must be nonnegative and shorter than its period",
        ))
        output = clamp(gain_value * state, minimum, maximum)
        return new(
            gain_value,
            time_constant,
            minimum,
            maximum,
            period,
            delay,
            state,
            state,
            output,
            output,
            0,
            -1,
            0,
            0,
            _public_parameter_provenance(
                "AIMORA public sampled saturating-lag example",
                "declared control unit and second",
                "positive time constant/period, delay shorter than period, and bounded output",
            ),
        )
    end
end

extension_identity(::Type{PublicSampledSaturatingLag}) = PUBLIC_SAMPLED_LAG_IDENTITY
extension_contract(::Type{PublicSampledSaturatingLag}) = AIMORA.NativeExtensions.ExtensionContract(
    PUBLIC_SAMPLED_LAG_IDENTITY,
    :control,
    :instantaneous_emt,
    :switching_detailed,
    1,
    (:initialize, :sampled_task, :event, :source, :output, :checkpoint, :reusable_definition),
    _public_example_inventory(Dict(
        :continuous => (:state,),
        :discrete => (:saturation_mode,),
        :delayed => (:pending_output, :pending_release_tick),
        :scheduler => (:next_sample_tick, :sample_count, :write_count),
        :history => (:held_input, :held_output),
        :output => (:held_output,),
        :checkpoint => (:complete_component_state,),
    )),
    "finite scalar input, positive time constant and exact tick period, delay shorter than period",
    unsupported = (:implicit_algebraic_loop, :random_state, :continuous_time_callback),
)

function sample_extension_task!(
    control::PublicSampledSaturatingLag,
    input::Real,
    tick::Integer,
    tick_s::Real,
)
    input_value = Float64(input)
    current_tick = Int(tick)
    tick_duration = Float64(tick_s)
    isfinite(input_value) || throw(ArgumentError("public sampled-lag input must be finite"))
    isfinite(tick_duration) && tick_duration > 0.0 || throw(ArgumentError(
        "public sampled-lag scheduler tick must be finite and positive",
    ))
    current_tick == control.next_sample_tick || throw(AIMORA.NativeExtensions.ExtensionFailure(
        :missed_extension_task,
        :sample_task,
        PUBLIC_SAMPLED_LAG_IDENTITY,
        "public sampled lag must execute on its exact next tick",
    ))
    interval_s = control.period_ticks * tick_duration
    blend = -expm1(-interval_s / control.time_constant_s)
    control.held_input = input_value
    control.state += blend * (input_value - control.state)
    control.pending_output = clamp(
        control.gain * control.state,
        control.minimum_output,
        control.maximum_output,
    )
    control.pending_release_tick = current_tick + control.delay_ticks
    control.next_sample_tick += control.period_ticks
    control.sample_count += 1
    control.delay_ticks == 0 && release_extension_task_output!(control, current_tick)
    return control.pending_output
end

function release_extension_task_output!(control::PublicSampledSaturatingLag, tick::Integer)
    current_tick = Int(tick)
    current_tick == control.pending_release_tick || throw(AIMORA.NativeExtensions.ExtensionFailure(
        :extension_task_release_mismatch,
        :release_task_output,
        PUBLIC_SAMPLED_LAG_IDENTITY,
        "public sampled-lag output must release on its exact pending tick",
    ))
    control.held_output = control.pending_output
    control.pending_release_tick = -1
    control.write_count += 1
    return control.held_output
end

extension_checkpoint(control::PublicSampledSaturatingLag) =
    AIMORA.NativeExtensions.ExtensionComponentCheckpoint(
        PUBLIC_SAMPLED_LAG_IDENTITY,
        (
            state = control.state,
            held_input = control.held_input,
            held_output = control.held_output,
            pending_output = control.pending_output,
            next_sample_tick = control.next_sample_tick,
            pending_release_tick = control.pending_release_tick,
            sample_count = control.sample_count,
            write_count = control.write_count,
        ),
        AIMORA.NativeExtensions.extension_state_signature((
            state = control.state,
            held_input = control.held_input,
            held_output = control.held_output,
            pending_output = control.pending_output,
            next_sample_tick = control.next_sample_tick,
            pending_release_tick = control.pending_release_tick,
            sample_count = control.sample_count,
            write_count = control.write_count,
        )),
    )

function restore_extension_checkpoint!(
    control::PublicSampledSaturatingLag,
    checkpoint::AIMORA.NativeExtensions.ExtensionComponentCheckpoint,
)
    checkpoint.identity == PUBLIC_SAMPLED_LAG_IDENTITY || throw(AIMORA.NativeExtensions.ExtensionFailure(
        :incompatible_extension_checkpoint,
        :restore_checkpoint,
        PUBLIC_SAMPLED_LAG_IDENTITY,
        "public sampled-lag checkpoint identity mismatch",
    ))
    AIMORA.NativeExtensions.extension_state_signature(checkpoint.state) == checkpoint.state_sha256 ||
        throw(AIMORA.NativeExtensions.ExtensionFailure(
            :corrupt_extension_checkpoint,
            :restore_checkpoint,
            PUBLIC_SAMPLED_LAG_IDENTITY,
            "public sampled-lag checkpoint digest mismatch",
        ))
    state = checkpoint.state
    control.state = state.state
    control.held_input = state.held_input
    control.held_output = state.held_output
    control.pending_output = state.pending_output
    control.next_sample_tick = state.next_sample_tick
    control.pending_release_tick = state.pending_release_tick
    control.sample_count = state.sample_count
    control.write_count = state.write_count
    return control
end

extension_outputs(control::PublicSampledSaturatingLag, time_s::Real) = (
    AIMORA.NativeExtensions.ExtensionOutputValue(
        :state,
        control.state,
        "declared_control_unit",
        time_s,
        :valid,
        PUBLIC_SAMPLED_LAG_IDENTITY,
    ),
    AIMORA.NativeExtensions.ExtensionOutputValue(
        :output,
        control.held_output,
        "declared_control_unit",
        time_s,
        :valid,
        PUBLIC_SAMPLED_LAG_IDENTITY,
    ),
)

function extension_source_value(control::PublicSampledSaturatingLag, time_s::Real)
    time = Float64(time_s)
    isfinite(time) && time >= 0.0 || throw(ArgumentError(
        "public sampled-lag source evaluation time must be finite and nonnegative",
    ))
    isfinite(control.held_output) || throw(ArgumentError(
        "public sampled-lag held source output must be finite",
    ))
    return control.held_output
end
