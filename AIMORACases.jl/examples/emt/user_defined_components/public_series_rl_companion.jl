const PUBLIC_SERIES_RL_IDENTITY = _public_example_identity(
    "series_rl_trapezoidal_companion",
    :PublicSeriesRLCompanion,
    "G=1/(R+2*L/h);Ihist=G*(vprev+(2*L/h-R)*iprev);i=G*v+Ihist",
)

mutable struct PublicSeriesRLCompanion <: AIMORA.NativeExtensions.AbstractExtensionElectricalDevice
    positive_node::Int
    negative_node::Int
    resistance_ohm::Float64
    inductance_h::Float64
    previous_current_a::Float64
    previous_voltage_v::Float64
    last_current_a::Float64
    provenance::AIMORA.StudyCore.ParameterProvenance

    function PublicSeriesRLCompanion(
        positive_node::Integer,
        negative_node::Integer,
        resistance_ohm::Real,
        inductance_h::Real;
        initial_current_a::Real = 0.0,
        initial_voltage_v::Real = 0.0,
    )
        positive = Int(positive_node)
        negative = Int(negative_node)
        positive >= 0 && negative >= 0 && positive != negative || throw(ArgumentError(
            "public series R-L terminals must be distinct nonnegative nodes",
        ))
        resistance, inductance, current, voltage = Float64.((
            resistance_ohm,
            inductance_h,
            initial_current_a,
            initial_voltage_v,
        ))
        all(isfinite, (resistance, inductance, current, voltage)) &&
            resistance >= 0.0 && inductance > 0.0 || throw(ArgumentError(
                "public series R-L values require finite R>=0, L>0, and finite initial state",
            ))
        return new(
            positive,
            negative,
            resistance,
            inductance,
            current,
            voltage,
            current,
            _public_parameter_provenance(
                "AIMORA public series R-L trapezoidal-companion example",
                "ohm, henry, ampere, and volt",
                "two distinct nodes, R>=0, L>0, finite state, and positive timestep",
            ),
        )
    end
end

extension_identity(::Type{PublicSeriesRLCompanion}) = PUBLIC_SERIES_RL_IDENTITY
extension_contract(::Type{PublicSeriesRLCompanion}) = AIMORA.NativeExtensions.ExtensionContract(
    PUBLIC_SERIES_RL_IDENTITY,
    :electrical,
    :instantaneous_emt,
    :switching_detailed,
    2,
    (:initialize, :companion_stamp, :state_acceptance, :output, :checkpoint, :reusable_definition),
    _public_example_inventory(Dict(
        :continuous => (:inductor_current,),
        :algebraic => (:terminal_voltage, :terminal_current, :companion_conductance),
        :history => (:previous_voltage, :previous_current),
        :output => (:terminal_current, :stored_energy, :dissipated_power),
        :checkpoint => (:complete_component_state,),
    )),
    "two-terminal series R-L branch with R>=0, L>0, finite accepted state, and positive timestep",
    unsupported = (:zero_inductance, :negative_resistance, :hidden_acceptance),
)

extension_terminal_nodes(component::PublicSeriesRLCompanion) =
    (component.positive_node, component.negative_node)

function extension_companion(component::PublicSeriesRLCompanion, step_s::Real)
    step = Float64(step_s)
    isfinite(step) && step > 0.0 || throw(ArgumentError(
        "public series R-L timestep must be finite and positive",
    ))
    inductive_resistance = 2.0 * component.inductance_h / step
    conductance = inv(component.resistance_ohm + inductive_resistance)
    history_current = conductance * (
        component.previous_voltage_v +
        (inductive_resistance - component.resistance_ohm) * component.previous_current_a
    )
    return (conductance_s = conductance, history_current_a = history_current)
end

function accept_extension_state!(component::PublicSeriesRLCompanion, terminal_voltage_v, step_s::Real)
    length(terminal_voltage_v) >= 2 || throw(DimensionMismatch(
        "public series R-L acceptance requires two terminal voltages",
    ))
    voltage = Float64(terminal_voltage_v[1] - terminal_voltage_v[2])
    isfinite(voltage) || throw(ArgumentError("public series R-L voltage must be finite"))
    companion = extension_companion(component, step_s)
    current = companion.conductance_s * voltage + companion.history_current_a
    isfinite(current) || throw(ArgumentError("public series R-L current must be finite"))
    component.previous_voltage_v = voltage
    component.previous_current_a = current
    component.last_current_a = current
    return current
end

extension_checkpoint(component::PublicSeriesRLCompanion) =
    AIMORA.NativeExtensions.ExtensionComponentCheckpoint(
        PUBLIC_SERIES_RL_IDENTITY,
        (
            previous_current_a = component.previous_current_a,
            previous_voltage_v = component.previous_voltage_v,
            last_current_a = component.last_current_a,
        ),
        AIMORA.NativeExtensions.extension_state_signature((
            previous_current_a = component.previous_current_a,
            previous_voltage_v = component.previous_voltage_v,
            last_current_a = component.last_current_a,
        )),
    )

function restore_extension_checkpoint!(
    component::PublicSeriesRLCompanion,
    checkpoint::AIMORA.NativeExtensions.ExtensionComponentCheckpoint,
)
    checkpoint.identity == PUBLIC_SERIES_RL_IDENTITY &&
        checkpoint.state_sha256 == AIMORA.NativeExtensions.extension_state_signature(checkpoint.state) ||
        throw(AIMORA.NativeExtensions.ExtensionFailure(
            :incompatible_extension_checkpoint,
            :restore_checkpoint,
            PUBLIC_SERIES_RL_IDENTITY,
            "public series R-L checkpoint is incompatible",
        ))
    state = checkpoint.state
    component.previous_current_a = state.previous_current_a
    component.previous_voltage_v = state.previous_voltage_v
    component.last_current_a = state.last_current_a
    return component
end

function extension_outputs(component::PublicSeriesRLCompanion, time_s::Real)
    return (
        AIMORA.NativeExtensions.ExtensionOutputValue(
            :terminal_current,
            component.last_current_a,
            "A",
            time_s,
            :valid,
            PUBLIC_SERIES_RL_IDENTITY,
        ),
        AIMORA.NativeExtensions.ExtensionOutputValue(
            :stored_energy,
            0.5 * component.inductance_h * component.last_current_a^2,
            "J",
            time_s,
            :valid,
            PUBLIC_SERIES_RL_IDENTITY,
        ),
        AIMORA.NativeExtensions.ExtensionOutputValue(
            :dissipated_power,
            component.resistance_ohm * component.last_current_a^2,
            "W",
            time_s,
            :valid,
            PUBLIC_SERIES_RL_IDENTITY,
        ),
    )
end
