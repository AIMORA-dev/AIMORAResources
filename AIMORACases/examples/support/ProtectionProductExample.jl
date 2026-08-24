#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA
using SHA

const PROTECTION_EXAMPLE_SOLVER_PATH = let
    configured = get(ENV, "AIMORA_SOLVER_PATH", "")
    candidate = isempty(AIMORA_EXAMPLE_ENGINE_PATH) ? "" :
        joinpath(dirname(AIMORA_EXAMPLE_ENGINE_PATH), "AIMORASolvers.jl")
    if !isempty(configured)
        abspath(configured)
    elseif !isempty(candidate) && isfile(joinpath(candidate, "src", "AIMORASolvers.jl"))
        candidate
    else
        ""
    end
end

if !AIMORA.solver_available()
    isempty(PROTECTION_EXAMPLE_SOLVER_PATH) && error(
        "the production solver is required to execute the generic protection products",
    )
    pushfirst!(LOAD_PATH, PROTECTION_EXAMPLE_SOLVER_PATH)
    using AIMORASolvers
    AIMORA.activate_solver!(AIMORASolvers.production_backend())
end

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))
using .ExampleSupport

const ProtectionExamples = AIMORA.ProtectionStudy
const ProtectionStudyCore = AIMORA.StudyCore
const ProtectionLogicalTime = AIMORA.EMTTaskPlatform.emt_logical_time
const ProtectionRealtime = AIMORA.RealtimeLoop

const PROTECTION_PRODUCT_TIMESTEP_S = 1.0e-3

const PROTECTION_PRODUCT_SETTING_PROVENANCE = ProtectionStudyCore.ParameterProvenance(
    "AIMORA-authored generic public protection product",
    "V, A, ohm, Hz, Hz/s, S",
    "direct synthetic SI settings with explicit terminal orientation",
    "exact synthetic case input; manufacturer, field, and coordination uncertainty unknown",
    "five generic fixed-step public protection products",
    ProtectionStudyCore.PhysicalModelParameter,
)

const PROTECTION_PRODUCT_TIMING_PROVENANCE = ProtectionStudyCore.ParameterProvenance(
    "AIMORA-authored generic public protection calendar",
    "seconds and exact integer ticks",
    "direct exact rational calendar on a one millisecond network step",
    "deterministic synthetic timing policy",
    "five generic fixed-step public protection products",
    ProtectionStudyCore.NumericalPolicyParameter,
)

function protection_terminal(id, asset, channels)
    return ProtectionExamples.ProtectionTerminalDefinition(
        id,
        asset,
        Symbol.(channels);
        inward_current_orientation="positive into the explicitly named protected zone",
    )
end

function protection_magnitude_settings(
    id,
    measurement_id,
    channel;
    stage=ProtectionExamples.ProtectionSlidingRMSStage,
    value_mode=ProtectionExamples.AbsoluteMagnitudeValue,
    orientation_polarity=1,
    pickup,
    dropout_ratio=0.9,
    unit,
)
    return ProtectionExamples.MagnitudeRelaySettings(
        id,
        measurement_id,
        channel;
        stage,
        value_mode,
        orientation_polarity,
        direction=ProtectionExamples.OverMagnitude,
        timer_mode=ProtectionExamples.ProtectionTimerInstantaneous,
        pickup,
        dropout_ratio,
        unit,
        setting_provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
        timer_provenance=PROTECTION_PRODUCT_TIMING_PROVENANCE,
    )
end

function protection_logic_definitions(id)
    local_logic = ProtectionExamples.ProtectionLogicDefinition(
        Symbol(id, :_local_logic),
        ProtectionExamples.AbstractProtectionLogicNode[
            ProtectionExamples.ProtectionLogicInputNode(:element_asserted, :element_asserted),
            ProtectionExamples.ProtectionLogicInputNode(:scheme_enabled, :scheme_enabled),
            ProtectionExamples.ProtectionLogicVoteNode(
                :trip,
                [:element_asserted, :scheme_enabled],
                2,
            ),
        ],
        :trip,
    )
    remote_logic = ProtectionExamples.ProtectionLogicDefinition(
        Symbol(id, :_remote_logic),
        ProtectionExamples.AbstractProtectionLogicNode[
            ProtectionExamples.ProtectionLogicInputNode(:trip_permission, :trip_permission),
        ],
        :trip_permission,
    )
    return (local_logic, remote_logic)
end

function protection_product_configuration(family, id, breaker_ids, communication_ids)
    element_settings = if family === ProtectionExamples.RadialFeederProtectionProduct
        (
            protection_magnitude_settings(
                :radial_phase_overcurrent,
                :radial_phase_currents,
                :phase_a;
                pickup=8.0,
                unit="A",
            ),
            protection_magnitude_settings(
                :radial_residual_earth_fault,
                :radial_residual_current,
                :residual;
                pickup=2.0,
                unit="A",
            ),
        )
    elseif family === ProtectionExamples.DirectionalDistanceLineProtectionProduct
        (
            ProtectionExamples.DirectionalRelaySettings(
                :line_forward_direction,
                :line_phasors,
                :local_voltage,
                :line_phasors,
                :local_current;
                characteristic_angle_rad=0.0,
                minimum_polarizing_voltage_v=1.0,
                minimum_operating_torque_w=10.0,
                provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
            ),
            ProtectionExamples.DistanceRelaySettings(
                :line_mho_zone,
                :line_phasors,
                :local_voltage,
                :line_phasors,
                :local_current,
                ProtectionExamples.MhoDistanceZone(5.0 + 0.0im, 2.0);
                minimum_loop_current_a=1.0,
                provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
            ),
            ProtectionExamples.IncrementalWaveSettings(
                :line_forward_incremental_wave,
                :line_incremental_terminal_values,
                :local_voltage,
                :line_incremental_terminal_values,
                :local_current;
                sample_period_ticks=1,
                reference_impedance_ohm=5.0,
                direction=ProtectionExamples.ForwardIncrementalWave,
                threshold_v=20.0,
                provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
            ),
        )
    elseif family === ProtectionExamples.TransformerBusDifferentialProtectionProduct
        (
            ProtectionExamples.DifferentialRelaySettings(
                :transformer_bus_biased_differential,
                [:transformer_primary_current, :transformer_secondary_current, :bus_feeder_current],
                [:current, :current, :current];
                compensation=ones(3),
                minimum_operate_a=1.0,
                initial_bias_a=0.5,
                region_slopes=[0.2],
                provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
            ),
        )
    elseif family === ProtectionExamples.MachineConverterFrequencyProtectionProduct
        (
            ProtectionExamples.ROCOFEstimatorSettings(
                :causal_machine_converter_rocof,
                :accepted_frequency;
                sample_period_ticks=1,
                window_intervals=1,
                minimum_frequency_hz=45.0,
                maximum_frequency_hz=65.0,
                orientation="positive for increasing accepted electrical frequency",
                numerical_provenance=PROTECTION_PRODUCT_TIMING_PROVENANCE,
            ),
            protection_magnitude_settings(
                :negative_machine_converter_rocof,
                :causal_machine_converter_rocof,
                :rocof;
                stage=ProtectionExamples.ProtectionROCOFStage,
                value_mode=ProtectionExamples.SignedScalarValue,
                orientation_polarity=-1,
                pickup=100.0,
                unit="Hz/s",
            ),
        )
    else
        (
            protection_magnitude_settings(
                :dc_link_overcurrent,
                :dc_terminal_currents,
                :positive_current;
                pickup=10.0,
                unit="A",
            ),
            ProtectionExamples.DifferentialRelaySettings(
                :dc_link_differential,
                [:dc_positive_current, :dc_return_current],
                [:current, :current];
                compensation=ones(2),
                minimum_operate_a=1.0,
                initial_bias_a=0.5,
                region_slopes=[0.2],
                provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
            ),
        )
    end
    communication_links = Tuple(
        ProtectionExamples.ProtectionCommunicationLink(
            link_id,
            :local_scheme,
            :remote_scheme;
            allowed_payloads=[:trip_permission],
            fixed_delay_ticks=0,
            provenance=PROTECTION_PRODUCT_TIMING_PROVENANCE,
        ) for link_id in communication_ids
    )
    breaker_specifications = Tuple(
        protection_breaker_specification(breaker_id) for breaker_id in breaker_ids
    )
    return (
        element_settings,
        logic_definitions=protection_logic_definitions(id),
        communication_links,
        breaker_specifications,
    )
end

function protection_product_specifications()
    common = (
        network_timestep_s=PROTECTION_PRODUCT_TIMESTEP_S,
        network_timestep_logical=ProtectionLogicalTime(1 // 1_000),
        protection_sample_period_ticks=1,
        setting_provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
        timing_provenance=PROTECTION_PRODUCT_TIMING_PROVENANCE,
        uncertainty="AIMORA-authored synthetic inputs; device, installation, field, and model-form uncertainty unknown",
    )
    return [
        ProtectionExamples.ProtectionProductSpecification(
            :generic_radial_overcurrent_earth_fault,
            ProtectionExamples.RadialFeederProtectionProduct,
            :radial_ac_feeder,
            :radial_feeder_zone;
            terminals=[protection_terminal(
                :source_terminal,
                :radial_feeder_source,
                [:phase_a_current, :phase_b_current, :phase_c_current, :residual_current],
            )],
            measurement_products=[:radial_phase_currents, :radial_residual_current],
            element_families=[
                :phase_overcurrent,
                :residual_earth_fault,
                :breaker_failure,
                :autoreclose,
            ],
            trip_breakers=[:radial_primary_breaker, :radial_backup_breaker],
            configuration=protection_product_configuration(
                ProtectionExamples.RadialFeederProtectionProduct,
                :generic_radial_overcurrent_earth_fault,
                [:radial_primary_breaker, :radial_backup_breaker],
                Symbol[],
            ),
            validity_domain="synthetic 50 Hz radial AC feeder with explicit primary, backup, failure, and one-shot reclose settings",
            common...,
        ),
        ProtectionExamples.ProtectionProductSpecification(
            :generic_directional_distance_line,
            ProtectionExamples.DirectionalDistanceLineProtectionProduct,
            :two_terminal_ac_line,
            :line_zone;
            terminals=[
                protection_terminal(:local_terminal, :line_local_end, [:local_voltage, :local_current]),
                protection_terminal(:remote_terminal, :line_remote_end, [:remote_voltage, :remote_current]),
            ],
            measurement_products=[:line_phasors, :line_incremental_terminal_values],
            element_families=[:directional, :distance, :incremental_wave, :communication],
            communication_links=[:line_permissive_link],
            trip_breakers=[:line_local_breaker, :line_remote_breaker],
            configuration=protection_product_configuration(
                ProtectionExamples.DirectionalDistanceLineProtectionProduct,
                :generic_directional_distance_line,
                [:line_local_breaker, :line_remote_breaker],
                [:line_permissive_link],
            ),
            validity_domain="synthetic 50 Hz two-terminal line with one mho zone, forward torque, one admitted incremental wave, and deterministic permissive message",
            common...,
        ),
        ProtectionExamples.ProtectionProductSpecification(
            :generic_transformer_bus_differential,
            ProtectionExamples.TransformerBusDifferentialProtectionProduct,
            :transformer_and_bus_zone,
            :transformer_bus_differential_zone;
            terminals=[
                protection_terminal(:transformer_primary, :transformer_primary_terminal, [:primary_current]),
                protection_terminal(:transformer_secondary, :transformer_secondary_terminal, [:secondary_current]),
                protection_terminal(:bus_feeder, :bus_feeder_terminal, [:feeder_current]),
            ],
            measurement_products=[:compensated_terminal_current_phasors],
            element_families=[:transformer_differential, :bus_differential],
            trip_breakers=[:transformer_primary_breaker, :transformer_secondary_breaker],
            configuration=protection_product_configuration(
                ProtectionExamples.TransformerBusDifferentialProtectionProduct,
                :generic_transformer_bus_differential,
                [:transformer_primary_breaker, :transformer_secondary_breaker],
                Symbol[],
            ),
            validity_domain="synthetic compensated three-terminal transformer and bus zone with half-sum biased restraint",
            common...,
        ),
        ProtectionExamples.ProtectionProductSpecification(
            :generic_machine_converter_frequency_rocof,
            ProtectionExamples.MachineConverterFrequencyProtectionProduct,
            :machine_converter_terminal,
            :frequency_supervision_zone;
            terminals=[protection_terminal(
                :monitored_terminal,
                :machine_converter_connection,
                [:positive_sequence_voltage, :frequency, :rocof],
            )],
            measurement_products=[:accepted_frequency, :causal_rocof],
            element_families=[:frequency, :rocof, :asset_logic],
            trip_breakers=[:machine_converter_breaker],
            configuration=protection_product_configuration(
                ProtectionExamples.MachineConverterFrequencyProtectionProduct,
                :generic_machine_converter_frequency_rocof,
                [:machine_converter_breaker],
                Symbol[],
            ),
            validity_domain="synthetic 45 through 65 Hz machine/converter terminal with a causal one-interval ROCOF window and explicit negative-rate orientation",
            common...,
        ),
        ProtectionExamples.ProtectionProductSpecification(
            :generic_dc_differential_overcurrent,
            ProtectionExamples.DCDifferentialOvercurrentProtectionProduct,
            :dc_link,
            :dc_link_zone;
            terminals=[
                protection_terminal(:dc_positive_terminal, :dc_link_positive, [:positive_current]),
                protection_terminal(:dc_return_terminal, :dc_link_return, [:return_current]),
            ],
            measurement_products=[:dc_terminal_currents],
            element_families=[:dc_differential, :dc_overcurrent, :breaker_failure],
            trip_breakers=[:dc_positive_breaker, :dc_return_breaker],
            configuration=protection_product_configuration(
                ProtectionExamples.DCDifferentialOvercurrentProtectionProduct,
                :generic_dc_differential_overcurrent,
                [:dc_positive_breaker, :dc_return_breaker],
                Symbol[],
            ),
            minimum_frequency_hz=0.0,
            maximum_frequency_hz=0.0,
            validity_domain="synthetic bipolar DC link with explicit inward current orientation, differential and overcurrent logic, and generic three-pole breaker surrogate",
            common...,
        ),
    ]
end

function protection_measurement(
    id,
    channel,
    quantity,
    unit,
    stage,
    tick,
    value;
    orientation="positive into the explicitly named protected zone",
)
    return ProtectionExamples.ProtectionMeasurement(
        id,
        channel,
        quantity,
        unit,
        orientation,
        stage,
        tick,
        tick,
        PROTECTION_PRODUCT_TIMESTEP_S,
        value,
        :valid,
        nothing,
        bytes2hex(sha256("$(id)|$(channel)|$(stage)")),
    )
end

function magnitude_outcome(state, settings, measurement)
    decision = ProtectionExamples.evaluate_magnitude_relay!(
        state,
        settings,
        measurement,
    )
    return (operated=decision.operated, margin=decision.measured_value - settings.pickup)
end

function radial_product_outcome(specification, runtime)
    phase_settings, earth_settings = specification.configuration.element_settings
    phase_state, earth_state = runtime.element_states
    phase = magnitude_outcome(
        phase_state,
        phase_settings,
        protection_measurement(
            :radial_phase_currents,
            :phase_a,
            :current,
            "A",
            ProtectionExamples.ProtectionSlidingRMSStage,
            0,
            12.0,
        ),
    )
    earth = magnitude_outcome(
        earth_state,
        earth_settings,
        protection_measurement(
            :radial_residual_current,
            :residual,
            :current,
            "A",
            ProtectionExamples.ProtectionSlidingRMSStage,
            0,
            4.0,
        ),
    )
    return (operated=phase.operated && earth.operated, margin=min(phase.margin, earth.margin))
end

function line_product_outcome(specification, runtime)
    directional_settings, distance_settings, wave_settings =
        specification.configuration.element_settings
    directional_state, distance_state, wave_state = runtime.element_states
    voltage = protection_measurement(
        :line_phasors,
        :local_voltage,
        :voltage,
        "V",
        ProtectionExamples.ProtectionFundamentalPhasorStage,
        1,
        50.0 + 0.0im,
    )
    current = protection_measurement(
        :line_phasors,
        :local_current,
        :current,
        "A",
        ProtectionExamples.ProtectionFundamentalPhasorStage,
        1,
        10.0 + 0.0im,
    )
    directional = ProtectionExamples.evaluate_directional_relay!(
        directional_state,
        directional_settings,
        voltage,
        current,
    )
    distance = ProtectionExamples.evaluate_distance_relay!(
        distance_state,
        distance_settings,
        voltage,
        current,
    )
    ProtectionExamples.evaluate_incremental_wave!(
        wave_state,
        wave_settings,
        protection_measurement(
            :line_incremental_terminal_values,
            :local_voltage,
            :voltage,
            "V",
            ProtectionExamples.ProtectionInstantaneousStage,
            0,
            0.0,
        ),
        protection_measurement(
            :line_incremental_terminal_values,
            :local_current,
            :current,
            "A",
            ProtectionExamples.ProtectionInstantaneousStage,
            0,
            0.0,
        ),
    )
    wave = ProtectionExamples.evaluate_incremental_wave!(
        wave_state,
        wave_settings,
        protection_measurement(
            :line_incremental_terminal_values,
            :local_voltage,
            :voltage,
            "V",
            ProtectionExamples.ProtectionInstantaneousStage,
            1,
            20.0,
        ),
        protection_measurement(
            :line_incremental_terminal_values,
            :local_current,
            :current,
            "A",
            ProtectionExamples.ProtectionInstantaneousStage,
            1,
            5.0,
        ),
    )
    margin = min(
        directional.operating_torque_w - directional_settings.minimum_operating_torque_w,
        distance.zone_margin_ohm,
        wave.selected_wave_v - wave_settings.threshold_v,
    )
    return (
        operated=directional.forward && distance.asserted && wave.asserted,
        margin,
    )
end

function differential_outcome(state, settings, values)
    measurements = [
        protection_measurement(
            measurement_id,
            :current,
            :current,
            "A",
            ProtectionExamples.ProtectionFundamentalPhasorStage,
            0,
            value,
        ) for (measurement_id, value) in zip(settings.terminal_measurement_ids, values)
    ]
    decision = ProtectionExamples.evaluate_differential_relay!(
        state,
        settings,
        measurements,
    )
    return (operated=decision.asserted, margin=decision.margin_a)
end

transformer_bus_product_outcome(specification, runtime) = differential_outcome(
    only(runtime.element_states),
    only(specification.configuration.element_settings),
    [10.0 + 0.0im, -2.0 + 0.0im, -1.0 + 0.0im],
)

function frequency_product_outcome(specification, runtime)
    settings, magnitude_settings = specification.configuration.element_settings
    state, magnitude_state = runtime.element_states
    ProtectionExamples.estimate_rocof!(
        state,
        settings,
        protection_measurement(
            :accepted_frequency,
            :frequency,
            :frequency,
            "Hz",
            ProtectionExamples.ProtectionFrequencyStage,
            0,
            50.0,
        ),
    )
    rocof = ProtectionExamples.estimate_rocof!(
        state,
        settings,
        protection_measurement(
            :accepted_frequency,
            :frequency,
            :frequency,
            "Hz",
            ProtectionExamples.ProtectionFrequencyStage,
            1,
            49.7,
        ),
    )
    return magnitude_outcome(
        magnitude_state,
        magnitude_settings,
        rocof,
    )
end

function dc_product_outcome(specification, runtime)
    overcurrent_settings, differential_settings =
        specification.configuration.element_settings
    overcurrent_state, differential_state = runtime.element_states
    overcurrent = magnitude_outcome(
        overcurrent_state,
        overcurrent_settings,
        protection_measurement(
            :dc_terminal_currents,
            :positive_current,
            :current,
            "A",
            ProtectionExamples.ProtectionSlidingRMSStage,
            0,
            20.0,
        ),
    )
    differential = differential_outcome(
        differential_state,
        differential_settings,
        [20.0 + 0.0im, -5.0 + 0.0im],
    )
    return (
        operated=overcurrent.operated && differential.operated,
        margin=min(overcurrent.margin, differential.margin),
    )
end

function protection_product_outcome(specification, runtime)
    family = specification.family
    family === ProtectionExamples.RadialFeederProtectionProduct &&
        return radial_product_outcome(specification, runtime)
    family === ProtectionExamples.DirectionalDistanceLineProtectionProduct &&
        return line_product_outcome(specification, runtime)
    family === ProtectionExamples.TransformerBusDifferentialProtectionProduct &&
        return transformer_bus_product_outcome(specification, runtime)
    family === ProtectionExamples.MachineConverterFrequencyProtectionProduct &&
        return frequency_product_outcome(specification, runtime)
    return dc_product_outcome(specification, runtime)
end

function protection_breaker_specification(id)
    return ProtectionExamples.EMTBreakerSpecification(
        id;
        closed_conductance_s=1.0e6,
        open_conductance_s=1.0e-9,
        opening_travel_ticks=1,
        closing_travel_ticks=1,
        current_zero_required=false,
        current_zero_threshold_a=0.0,
        failure_delay_ticks=2,
        failure_current_threshold_a=0.1,
        reclose_dead_ticks=2,
        reclaim_ticks=3,
        maximum_reclose_shots=1,
        physical_provenance=PROTECTION_PRODUCT_SETTING_PROVENANCE,
        timing_provenance=PROTECTION_PRODUCT_TIMING_PROVENANCE,
    )
end

function run_protection_product(specification)
    preparation = ProtectionExamples.prepare_protection_product(specification)
    readiness = ProtectionExamples.protection_product_readiness(
        preparation;
        production_backend_available=AIMORA.solver_available(),
    )
    breaker_specification = first(specification.configuration.breaker_specifications)
    product_runtime = ProtectionExamples.ProtectionProductRuntime(
        preparation;
        task_plan_signature_sha256=repeat("0", 64),
    )
    outcome = Ref{Any}(nothing)
    local_result = Ref{Any}(nothing)
    remote_result = Ref{Any}(nothing)
    delivered = Ref(ProtectionExamples.QueuedProtectionMessage[])
    local_logic, remote_logic = specification.configuration.logic_definitions
    uses_link = !isempty(specification.configuration.communication_links)
    link = uses_link ? only(specification.configuration.communication_links) : nothing
    state = (
        released=Ref(false),
        outcome,
        product_runtime,
        local_logic,
        local_result,
        link,
        delivered,
        remote_logic,
        remote_result,
        breaker_specification,
    )
    operations = ProtectionExamples.ProtectionTaskOperations(
        (runtime, _instant, _index) -> (runtime.released[] = true),
        (runtime, _instant, _index) -> begin
            runtime.released[] || error("protection measurement was not released")
            runtime.outcome[] = protection_product_outcome(
                specification,
                runtime.product_runtime,
            )
        end,
        (runtime, _instant, _index) -> begin
            runtime.local_result[] = ProtectionExamples.evaluate_protection_logic!(
                runtime.product_runtime.logic_states[1],
                runtime.local_logic,
                Dict(
                    :element_asserted => runtime.outcome[].operated,
                    :scheme_enabled => true,
                ),
            )
        end,
        (runtime, _instant, index) -> begin
            uses_link && ProtectionExamples.send_protection_message!(
                only(runtime.product_runtime.communication_states),
                runtime.link,
                :trip_permission,
                index - 1,
            )
        end,
        (runtime, _instant, index) -> begin
            runtime.delivered[] = uses_link ?
                ProtectionExamples.deliver_due_protection_messages!(
                    only(runtime.product_runtime.communication_states),
                    runtime.link,
                    index - 1,
                ) : ProtectionExamples.QueuedProtectionMessage[]
        end,
        (runtime, _instant, _index) -> begin
            permission = uses_link ? !isempty(runtime.delivered[]) :
                runtime.local_result[].output
            runtime.remote_result[] = ProtectionExamples.evaluate_protection_logic!(
                runtime.product_runtime.logic_states[2],
                runtime.remote_logic,
                Dict(:trip_permission => permission),
            )
        end,
        (runtime, _instant, index) -> begin
            runtime.remote_result[].output && ProtectionExamples.request_breaker_trip!(
                first(runtime.product_runtime.breaker_states),
                runtime.breaker_specification,
                index - 1,
            )
        end,
    )
    pipeline = ProtectionExamples.ProtectionTaskPipeline(
        operations,
        state;
        epoch=ProtectionLogicalTime(0),
        period=ProtectionLogicalTime(1 // 1_000),
        start=ProtectionLogicalTime(0),
        stop=ProtectionLogicalTime(0),
    )
    product_runtime.task_plan_signature_sha256 = pipeline.plan.signature_sha256
    study_preparation = ProtectionExamples.prepare_protection_study(
        preparation,
        pipeline;
        execution_instant=ProtectionLogicalTime(0),
        topology_signature_sha256=bytes2hex(sha256(
            "$(specification.id)|generic_public_breaker_network",
        )),
        output_ids=[
            :element_asserted,
            :trip_command,
            :pole_position,
            :contact_energy,
            :load_voltage,
        ],
    )
    study_preparation isa ProtectionExamples.ProtectionStudyPreparation ||
        error(study_preparation.message)
    study_result = ProtectionExamples.run_protection(study_preparation)
    study_result isa ProtectionExamples.ProtectionStudyResult ||
        error(study_result.message)
    pipeline_result = study_result.task_result
    product_runtime = pipeline_result.state.product_runtime
    runtime = first(product_runtime.breaker_states)
    binding = AIMORA.materialize_emt_breaker_poles(
        runtime,
        breaker_specification,
        ((1, 2), (3, 4), (5, 6)),
    )
    source_voltage_v = (100.0, -50.0, 25.0)
    source_conductance_s = 0.1
    load_conductance_s = 0.1
    elements = Any[]
    for index in 1:3
        source_node, load_node = binding.terminal_nodes[index]
        push!(elements, AIMORA.Branches.TwoTerminalTheveninSource(
            source_node,
            0,
            source_conductance_s,
            _time_s -> source_voltage_v[index],
        ))
        push!(elements, binding.network_elements[index])
        push!(elements, AIMORA.Branches.ConductanceBranch(load_node, 0, load_conductance_s))
    end
    network = AIMORA.Nodal.NodalSystem(6, elements)
    AIMORA.Nodal.solve_algebraic_state!(network, 0.0, PROTECTION_PRODUCT_TIMESTEP_S)
    AIMORA.Nodal.accept_algebraic_state!(network, PROTECTION_PRODUCT_TIMESTEP_S)
    closed_voltage = copy(network.v[[2, 4, 6]])
    ProtectionExamples.advance_emt_breaker!(
        runtime,
        breaker_specification,
        0,
        (0.0, 0.0, 0.0),
        Tuple(sign.(source_voltage_v) .* abs.(closed_voltage) .* load_conductance_s),
    )
    open_result = ProtectionExamples.advance_emt_breaker!(
        runtime,
        breaker_specification,
        1,
        (0.0, 0.0, 0.0),
        (0.0, 0.0, 0.0),
    )
    ProtectionExamples.synchronize_emt_breaker_poles!(
        binding,
        runtime,
        breaker_specification,
    )
    AIMORA.Nodal.solve_algebraic_state!(
        network,
        PROTECTION_PRODUCT_TIMESTEP_S,
        PROTECTION_PRODUCT_TIMESTEP_S,
    )
    AIMORA.Nodal.accept_algebraic_state!(network, PROTECTION_PRODUCT_TIMESTEP_S)
    open_voltage = copy(network.v[[2, 4, 6]])
    product_runtime.accepted_tick = 1
    product_runtime.output_cursor = 1
    push!(
        product_runtime.event_trace,
        ProtectionExamples.ProtectionProductEvent(
            1,
            breaker_specification.id,
            :contact_opened,
            :three_pole,
        ),
    )
    runtime_snapshot = ProtectionExamples.protection_product_runtime_snapshot(
        product_runtime,
    )
    restored_runtime = ProtectionExamples.ProtectionProductRuntime(
        preparation;
        task_plan_signature_sha256=pipeline.plan.signature_sha256,
    )
    ProtectionExamples.restore_protection_product_runtime_snapshot!(
        restored_runtime,
        runtime_snapshot,
    )
    restart_exact = ProtectionExamples.protection_product_runtime_snapshot(
        restored_runtime,
    ).deterministic_signature_sha256 == runtime_snapshot.deterministic_signature_sha256
    return (
        specification,
        preparation,
        readiness,
        study_preparation,
        study_result,
        pipeline_result,
        outcome=pipeline_result.state.outcome[],
        closed_voltage,
        open_voltage,
        open_result,
        runtime_snapshot,
        restart_exact,
    )
end

function write_protection_product_artifacts(output_directory, result)
    stem = String(result.specification.id)
    project_signature = bytes2hex(sha256(
        "AIMORA|generic_protection_products|public_project|v1",
    ))
    portable_path = joinpath(output_directory, "$(stem).aimora")
    portable_source_runtime = ProtectionExamples.ProtectionProductRuntime(
        result.preparation;
        task_plan_signature_sha256=result.runtime_snapshot.task_plan_signature_sha256,
    )
    ProtectionExamples.restore_protection_product_runtime_snapshot!(
        portable_source_runtime,
        result.runtime_snapshot,
    )
    portable_descriptor = ProtectionExamples.write_protection_product_portable_snapshot(
        portable_path,
        portable_source_runtime;
        project_signature_sha256=project_signature,
        topology_signature_sha256=result.study_preparation.topology_signature_sha256,
    )
    portable_restored_runtime = ProtectionExamples.ProtectionProductRuntime(
        result.preparation;
        task_plan_signature_sha256=result.runtime_snapshot.task_plan_signature_sha256,
    )
    portable_restored_runtime, inspected_descriptor =
        ProtectionExamples.restore_protection_product_portable_snapshot!(
            portable_restored_runtime,
            portable_path;
            project_signature_sha256=project_signature,
            topology_signature_sha256=result.study_preparation.topology_signature_sha256,
        )
    portable_restart_exact =
        inspected_descriptor.content_sha256 == portable_descriptor.content_sha256 &&
        ProtectionExamples.protection_product_runtime_snapshot(
            portable_restored_runtime,
        ).deterministic_signature_sha256 ==
            result.runtime_snapshot.deterministic_signature_sha256
    portable_restart_exact || error(
        "the public protection product portable restart is not exact for $(stem)",
    )
    time_s = [0.0, PROTECTION_PRODUCT_TIMESTEP_S, 2 * PROTECTION_PRODUCT_TIMESTEP_S]
    asserted = [0.0, 1.0, 1.0]
    trip_command = [0.0, 1.0, 1.0]
    contact_closed = [1.0, 1.0, 0.0]
    load_voltage = [
        maximum(abs, result.closed_voltage),
        maximum(abs, result.closed_voltage),
        maximum(abs, result.open_voltage),
    ]
    csv_series = [
        "element_asserted" => asserted,
        "trip_command" => trip_command,
        "contact_closed" => contact_closed,
        "maximum_load_voltage_v" => load_voltage,
    ]
    voltage_base = maximum(load_voltage)
    plot_series = [
        "element_asserted" => asserted,
        "trip_command" => trip_command,
        "contact_closed" => contact_closed,
        "load_voltage_pu" => load_voltage ./ voltage_base,
    ]
    csv = write_series_csv(
        joinpath(output_directory, "$(stem).csv"),
        "time_s",
        time_s,
        csv_series,
    )
    svg = write_waveform_svg(
        joinpath(output_directory, "$(stem).svg"),
        time_s,
        plot_series;
        title="$(replace(stem, '_' => ' ')) fixed-step protection sequence",
        y_label="state or load voltage (pu)",
    )
    summary = write_key_value_summary(
        joinpath(output_directory, "$(stem)_summary.md"),
        replace(stem, '_' => ' '),
        (
            family=result.specification.family,
            element_operated=result.outcome.operated,
            minimum_operating_margin=result.outcome.margin,
            exact_task_stage_count=result.pipeline_result.task_count,
            breaker_open=all(==(
                ProtectionExamples.BreakerPoleOpen,
            ), result.open_result.pole_positions),
            solver_free_preparation=true,
            coupled_backend_available=result.readiness.production_backend_available,
            product_signature=result.specification.deterministic_signature_sha256,
            preparation_signature=result.preparation.preparation_signature_sha256,
            study_result_signature=result.study_result.deterministic_signature_sha256,
            restart_exact=result.restart_exact,
            portable_restart_exact,
            runtime_snapshot_signature=result.runtime_snapshot.deterministic_signature_sha256,
            portable_snapshot_sha256=portable_descriptor.content_sha256,
            portable_snapshot_bytes=portable_descriptor.canonical_bytes,
            limitation="Generic synthetic, nonvendor, noncoordinated, nonmeasured, noncertifying fixed-step product; no standard, protocol, field, ATP/PSCAD, HIL, or detailed-arc claim.",
        ),
    )
    return (;
        csv,
        svg,
        summary,
        snapshot=abspath(portable_path),
        portable_restart_exact,
        portable_snapshot_sha256=portable_descriptor.content_sha256,
    )
end

function write_protection_logic_diagram(output_directory)
    path = joinpath(output_directory, "protection_logic.svg")
    stages = (
        "accepted\nmeasurement",
        "relay\nelements",
        "local\nlogic",
        "message\nsend/deliver",
        "remote\nlogic",
        "trip\ncommand",
        "breaker\ncontacts",
    )
    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="1260" height="250" viewBox="0 0 1260 250">""")
        println(io, """<rect width="1260" height="250" fill="#ffffff"/>""")
        println(io, """<text x="630" y="34" text-anchor="middle" font-family="sans-serif" font-size="22" fill="#111827">AIMORA fixed-step protection mutation path</text>""")
        for (index, stage) in enumerate(stages)
            x = 25 + (index - 1) * 175
            color = index == length(stages) ? "#dc2626" : "#2563eb"
            println(io, """<rect x="$x" y="80" width="145" height="90" rx="10" fill="#f8fafc" stroke="$color" stroke-width="3"/>""")
            lines = split(stage, '\n')
            for (line_index, line) in enumerate(lines)
                y = 116 + (line_index - 1) * 24
                println(io, """<text x="$(x + 72.5)" y="$y" text-anchor="middle" font-family="sans-serif" font-size="17" fill="#111827">$line</text>""")
            end
            if index < length(stages)
                println(io, """<line x1="$(x + 145)" y1="125" x2="$(x + 170)" y2="125" stroke="#475569" stroke-width="3"/>""")
                println(io, """<path d="M $(x + 170) 125 l -10 -7 v 14 z" fill="#475569"/>""")
            end
        end
        println(io, """<text x="630" y="215" text-anchor="middle" font-family="sans-serif" font-size="15" fill="#475569">Every accepted stage is causal, ordered, rollback-capable, and bound to the same exact logical time.</text>""")
        println(io, "</svg>")
    end
    return abspath(path)
end

function run_protection_c_loopback(output_directory, radial_specification)
    Sys.islinux() || error("the public protection C loopback requires native Linux")
    compiler = something(Sys.which(get(ENV, "CC", "gcc")), nothing)
    compiler === nothing && error("a C compiler is required for the protection C loopback")
    source = normpath(joinpath(
        @__DIR__,
        "..",
        "emt",
        "generic_protection_products",
        "controller",
        "aimora_protection_controller.c",
    ))
    measurements_a = [0.0, 7.0, 8.0, 7.5, 7.1, 9.0]
    c_pickup = zeros(length(measurements_a))
    c_trip = zeros(length(measurements_a))
    julia_trip = zeros(length(measurements_a))
    settings = first(radial_specification.configuration.element_settings)
    julia_state = ProtectionExamples.MagnitudeRelayState()
    restart_exact = false
    maximum_error = 0.0
    library_hash = ""
    compiler_identity = replace(first(readlines(`$compiler --version`)), ',' => ';')
    mktempdir() do build_directory
        library = joinpath(build_directory, "aimora_protection_controller.so")
        run(`$compiler -std=c11 -O2 -fPIC -shared -o $library $source`)
        library_hash = bytes2hex(sha256(read(library)))
        channels = [
            ProtectionRealtime.RealtimeChannel(:pickup_active, :input, "1", 1.0, 0.0, 0.0, 1.0, 0.0),
            ProtectionRealtime.RealtimeChannel(:trip_command, :input, "1", 1.0, 0.0, 0.0, 1.0, 0.0),
            ProtectionRealtime.RealtimeChannel(:measured_current, :output, "A", 1.0, 0.0, -100.0, 100.0, 0.0),
        ]
        interface = ProtectionRealtime.open_shared_library_controller(
            library,
            library_hash,
            channels,
        )
        target = ProtectionRealtime.RealtimeTarget(
            :generic_protection_c_loopback,
            ProtectionRealtime.SharedLibraryControllerTarget;
            period_ns=1_000_000,
            step_count=length(measurements_a),
            overrun_policy=ProtectionRealtime.MeasureOnlyOverrun,
        )
        preparation = ProtectionRealtime.prepare_realtime_target(target, channels, interface)
        preparation isa ProtectionRealtime.RealtimePreparation || error(preparation.message)
        ProtectionRealtime.prepare_realtime_interface!(interface)
        inputs = zeros(2)
        c_checkpoint = nothing
        julia_checkpoint = nothing
        try
            for index in eachindex(measurements_a)
                ProtectionRealtime.exchange_realtime_interface!(
                    interface,
                    inputs,
                    [measurements_a[index]],
                    index - 1,
                    Int64((index - 1) * 1_000_000),
                )
                decision = ProtectionExamples.evaluate_magnitude_relay!(
                    julia_state,
                    settings,
                    protection_measurement(
                        settings.measurement_id,
                        settings.channel,
                        :current,
                        settings.unit,
                        settings.stage,
                        index - 1,
                        measurements_a[index],
                    ),
                )
                c_pickup[index] = inputs[1]
                c_trip[index] = inputs[2]
                julia_trip[index] = decision.operated
                maximum_error = max(
                    maximum_error,
                    abs(inputs[1] - decision.pickup_active),
                    abs(inputs[2] - decision.operated),
                )
                if index == 3
                    c_checkpoint = ProtectionRealtime.shared_library_controller_state(interface)
                    julia_checkpoint = ProtectionExamples.magnitude_relay_snapshot(
                        julia_state,
                        settings,
                    )
                end
            end
            ProtectionRealtime.restore_shared_library_controller_state!(interface, c_checkpoint)
            restored_julia = ProtectionExamples.MagnitudeRelayState()
            ProtectionExamples.restore_magnitude_relay_snapshot!(
                restored_julia,
                settings,
                julia_checkpoint,
            )
            restored_inputs = zeros(2)
            restart_exact = true
            for index in 4:length(measurements_a)
                ProtectionRealtime.exchange_realtime_interface!(
                    interface,
                    restored_inputs,
                    [measurements_a[index]],
                    index - 1,
                    Int64((index - 1) * 1_000_000),
                )
                restored_decision = ProtectionExamples.evaluate_magnitude_relay!(
                    restored_julia,
                    settings,
                    protection_measurement(
                        settings.measurement_id,
                        settings.channel,
                        :current,
                        settings.unit,
                        settings.stage,
                        index - 1,
                        measurements_a[index],
                    ),
                )
                restart_exact &= restored_inputs == [c_pickup[index], c_trip[index]]
                restart_exact &= restored_decision.operated == (julia_trip[index] == 1.0)
            end
        finally
            ProtectionRealtime.close_realtime_interface!(interface)
        end
    end
    maximum_error == 0.0 || error(
        "the protection C loopback differs from the Julia relay contract",
    )
    restart_exact || error("the protection C loopback restart continuation differs")
    csv = write_series_csv(
        joinpath(output_directory, "protection_c_loopback.csv"),
        "sample",
        collect(0:length(measurements_a) - 1),
        [
            "measurement_a" => measurements_a,
            "c_pickup" => c_pickup,
            "c_trip" => c_trip,
            "julia_trip" => julia_trip,
        ],
    )
    summary = write_key_value_summary(
        joinpath(output_directory, "protection_c_loopback_summary.md"),
        "AIMORA protection C-loopback parity",
        (
            sample_count=length(measurements_a),
            maximum_parity_error=maximum_error,
            restart_exact,
            controller_sha256=library_hash,
            controller_compiler=compiler_identity,
            profile="native Linux shared-library software loopback; not physical HIL",
        ),
    )
    return (; csv, summary, maximum_error, restart_exact, library_hash, compiler_identity)
end

function run_public_protection_products(output_directory)
    AIMORA.require_solver()
    results = [run_protection_product(specification) for
               specification in protection_product_specifications()]
    artifacts = [write_protection_product_artifacts(output_directory, result) for
                 result in results]
    logic_diagram = write_protection_logic_diagram(output_directory)
    c_loopback = run_protection_c_loopback(output_directory, first(results).specification)
    return (; results, artifacts, logic_diagram, c_loopback)
end
