module LocalMultiratePartitionedNetwork

using AIMORA
using LinearAlgebra
using SHA

using AIMORA.EMTPartitioning
using AIMORA.EMTTaskPlatform

export coupled_partition_study,
       coupled_partition_terminal_map,
       coupled_region_model_identities,
       scale_partition_study

const LOCAL_STEP = emt_logical_time(1 // 400_000)
const COMMUNICATION_STEP = emt_logical_time(1 // 400_000)
const STOP_TIME = emt_logical_time(4 // 25_000)
const MEASUREMENT_PERIOD = emt_logical_time(1 // 50_000)
const MEASUREMENT_DELAY = emt_logical_time(1 // 100_000)
const PWM_PERIOD = emt_logical_time(1 // 25_000)
const MINIMUM_PWM_PULSE_WIDTH_S = 10.0e-6
const TOPOLOGY_EVENT_TIME_S = 80.0e-6
const COUPLED_RATE_RATIOS = (4, 2, 1, 1, 1, 1, 1, 1)

logical_substep(value, divisor::Int) = emt_logical_time(
    value.numerator,
    value.denominator * divisor,
)

function exact_tick_count(duration, tick, label::AbstractString)
    numerator = BigInt(duration.numerator) * tick.denominator
    denominator = BigInt(duration.denominator) * tick.numerator
    denominator > 0 || throw(ArgumentError("$label tick must be positive"))
    ticks, remainder = divrem(numerator, denominator)
    iszero(remainder) || throw(ArgumentError(
        "$label must be an integer multiple of its selected local timestep",
    ))
    0 <= ticks <= typemax(Int) || throw(OverflowError(
        "$label tick count exceeds the Int domain",
    ))
    return Int(ticks)
end

function physical_provenance(source::AbstractString, units::AbstractString)
    return AIMORA.StudyCore.ParameterProvenance(
        String(source),
        String(units),
        "direct synthetic SI values",
        "exact synthetic inputs; manufacturer and model-form uncertainty are unknown",
        "the redistributable coupled partition example at its declared fixed steps",
        AIMORA.StudyCore.PhysicalModelParameter,
    )
end

function modern_machine_owner(
    phase_a::String,
    phase_b::String,
    phase_c::String,
    local_step,
)
    machines = AIMORA.ModernMachines
    electrical = machines.MachineElectricalParameters(
        stator_resistance_ohm=0.2,
        zero_sequence_inductance_h=0.012,
        stator_d_leakage_inductance_h=0.006,
        stator_q_leakage_inductance_h=0.007,
        d_axis_magnetizing_inductance_h=0.08,
        q_axis_magnetizing_inductance_h=0.07,
        permanent_magnet_flux_wb=0.45,
    )
    specification = machines.ModernMachineSpecification(
        :coupled_partition_permanent_magnet_machine,
        machines.PermanentMagnetSynchronousMachine;
        operating_mode=machines.MachineGeneratorMode,
        pole_pairs=2,
        electrical,
        shaft_masses=[machines.MachineShaftMass(
            :rotor;
            inertia_kg_m2=2.0,
            damping_nm_s_per_rad=0.01,
            initial_speed_rad_s=60.0pi,
        )],
        saturation=machines.MachineMagneticCoenergyLaw(
            radial_coefficient_per_wb2_h=0.01,
            cross_coefficient_per_wb2_h=0.005,
            maximum_flux_wb=20.0,
        ),
        settings=machines.MachineRuntimeSettings(
            timestep_s=Float64(local_step),
            nonlinear_tolerance=1.0e-12,
            maximum_nonlinear_iterations=16,
            energy_tolerance_j=1.0e-6,
        ),
        provenance=physical_provenance(
            "AIMORA coupled partition modern-machine example",
            "SI",
        ),
        uncertainty="exact synthetic inputs; field and model-form uncertainty are unknown",
        validity_domain="one weakly grid-coupled permanent-magnet machine at the selected exact fixed step",
    )
    preparation = machines.prepare_modern_machine(specification)
    event = machines.ModernMachineEvent(
        :machine_torque_transition,
        TOPOLOGY_EVENT_TIME_S,
        machines.MachineMechanicalTorqueEvent;
        value=2.0,
        priority=-1,
    )
    return EMTRegionalModernMachineOwner(
        "modern_machine",
        (phase_a, phase_b, phase_c, "0"),
        preparation;
        events=(event,),
    )
end

function transformer_source_record()
    return AIMORA.TransformerApparatus.TransformerSourceRecord(
        :coupled_partition_measurement_transformer,
        bytes2hex(sha256("coupled partition measurement transformer")),
        physical_provenance(
            "AIMORA coupled partition measurement-transformer example",
            "SI",
        ),
    )
end

function instrument_transformer_owner(
    primary::String,
    secondary::String,
    local_step,
)
    transformers = AIMORA.TransformerApparatus
    measurements = AIMORA.MeasurementChains
    connection = transformers.TransformerConnectionTopology(
        node_order=[:primary_terminal, :secondary_terminal],
        coil_order=[:primary_coil, :secondary_coil],
        winding_order=[:primary_winding, :secondary_winding],
        phase_order=[:phase_a],
        coil_winding=[:primary_winding, :secondary_winding],
        coil_phase=[:phase_a, :phase_a],
        incidence=Matrix{Float64}(I, 2, 2),
        vector_group="Ii0",
        clock_number=0,
        phase_shift_rad=0.0,
    )
    matrices = transformers.TransformerTerminalMatrices(
        [0.1 0.0; 0.0 0.2],
        [0.2 0.18; 0.18 0.2],
    )
    apparatus = transformers.TransformerApparatusSpecification(
        :coupled_partition_measurement_transformer,
        transformers.LowFrequencyTerminalTier,
        connection,
        transformers.LowFrequencyTransformerModel(matrices),
        transformers.TransformerRuntimeSettings(
            timestep_s=Float64(local_step),
            initialization_frequency_hz=60.0,
            kcl_absolute_tolerance_a=1.0e-10,
        );
        phase_count=1,
        rated_power_va=1.0e3,
        rated_voltage_v=120.0,
        rated_frequency_hz=60.0,
        sources=[transformer_source_record()],
        uncertainty="exact synthetic public transformer inputs",
        validity_domain="one weakly coupled linear instrument transformer at the selected exact fixed step",
    )
    burden = measurements.MeasurementBurden(
        series_resistance_ohm=2.0,
        provenance=physical_provenance(
            "AIMORA coupled partition measurement burden",
            "ohm",
        ),
    )
    definition = measurements.InstrumentTransformerMeasurementDefinition(
        :coupled_partition_sampled_current,
        measurements.LinearCurrentTransformerMeasurement,
        apparatus;
        primary_coil_index=1,
        secondary_coil_index=2,
        primary_turns=1.0,
        secondary_turns=10.0,
        burden,
        maximum_secondary_impedance_ohm=100.0,
        secondary_output_sign=-1.0,
    )
    preparation = transformers.prepare_transformer_apparatus(
        apparatus;
        initialization_mode=transformers.DeenergizedTransformerInitialization,
    )
    acquisition = measurements.MeasurementAcquisitionSettings(
        tick_s=Float64(local_step),
        sample_period_ticks=exact_tick_count(
            MEASUREMENT_PERIOD,
            local_step,
            "measurement period",
        ),
        first_sample_tick=0,
        delay_ticks=exact_tick_count(
            MEASUREMENT_DELAY,
            local_step,
            "measurement delay",
        ),
        window_weights_newest_first=ones(4),
        nominal_frequency_hz=60.0,
        maximum_retained_samples=64,
    )
    measurement = measurements.MeasurementChainSpecification(
        :coupled_partition_sampled_current_chain,
        measurements.LinearCurrentTransformerMeasurement;
        channel_names=[:secondary_current],
        quantity=:current,
        unit="A",
        orientation="positive from the secondary dotted terminal into the declared burden",
        quantizer=measurements.UnquantizedMeasurement(-1.0e6, 1.0e6),
        acquisition,
        minimum_input=-1.0e6,
        maximum_input=1.0e6,
        maximum_spectral_frequency_hz=1.0e3,
        maximum_timestep_s=Float64(local_step),
        provenance=physical_provenance(
            "AIMORA coupled partition sampled measurement",
            "A",
        ),
    )
    return EMTRegionalInstrumentTransformerOwner(
        "instrument_transformer_measurement",
        (primary, secondary),
        definition,
        preparation,
        measurement,
    )
end

function frequency_dependent_line_owner(sending::String, receiving::String)
    lines = AIMORA.Lines
    mode = lines.SemlyenModeParameters(
        5.0e-3,
        80.0e-6,
        1.0 + 0.2im,
        0.01 + 0.002im,
        60.0,
        [
            lines.SemlyenRationalTerm(15_161.0, 0.75119),
            lines.SemlyenRationalTerm(1_710.5, 0.24881),
        ],
        [
            lines.SemlyenRationalTerm(595.84, -0.0011954),
            lines.SemlyenRationalTerm(39_933.0, -0.00074162),
        ],
    )
    return EMTRegionalSemlyenLineOwner(
        "history_line",
        (sending,),
        (receiving,),
        (mode,);
        voltage_modal_to_phase=ones(1, 1),
        current_modal_to_phase=ones(1, 1),
    )
end

function converter_owner(dc_positive::String, ac_terminal::String, local_step)
    return EMTRegionalBridgeLegOwner(
        "switch_detailed_converter_leg",
        dc_positive,
        ac_terminal,
        "0";
        initially_upper_on=true,
        on_conductance_s=20.0,
        off_conductance_s=1.0e-8,
        forward_voltage_drop_v=0.4,
        diode_forward_voltage_v=0.3,
        diode_conductance_s=20.0,
        snubber_resistance_ohm=10.0,
        snubber_capacitance_f=1.0e-7,
        gate_turn_on_delay_s=0.0,
        gate_turn_off_delay_s=0.0,
        commutation_dead_time_s=0.0,
        minimum_pulse_width_s=MINIMUM_PWM_PULSE_WIDTH_S,
        pwm_task_identity="converter_carrier",
        pwm_tick=local_step,
        pwm_period=PWM_PERIOD,
        pwm_first_time=emt_logical_time(0),
        pwm_duty=0.5,
        pwm_priority=0,
    )
end

function partition_terminal(region_index::Int, side::Symbol, monolithic::Bool)
    if monolithic
        side === :input && return "BUS_$(region_index - 1)"
        side === :output && return "BUS_$region_index"
    end
    prefix = "REGION_$region_index"
    return side === :input ? "$(prefix)_IN" : "$(prefix)_OUT"
end

function coupled_partition_terminal_map(; monolithic::Bool=false)
    return Tuple((
        input=region_index == 1 ? "" : partition_terminal(region_index, :input, monolithic),
        output=region_index == 8 ? "" : partition_terminal(region_index, :output, monolithic),
    ) for region_index in 1:8)
end

function regional_declarations(;
    monolithic::Bool=false,
    local_steps=ntuple(_ -> LOCAL_STEP, 8),
)
    terminals = coupled_partition_terminal_map(; monolithic)
    measurement_primary = monolithic ? "MEASUREMENT_PRIMARY" : "REGION_3_PRIMARY"
    measurement_secondary = monolithic ? "MEASUREMENT_SECONDARY" : "REGION_3_SECONDARY"
    machine_phase_a = monolithic ? "MACHINE_PHASE_A" : "REGION_5_PHASE_A"
    machine_phase_b = monolithic ? "MACHINE_PHASE_B" : "REGION_5_PHASE_B"
    machine_phase_c = monolithic ? "MACHINE_PHASE_C" : "REGION_5_PHASE_C"
    converter_dc = monolithic ? "CONVERTER_DC_POSITIVE" : "REGION_6_DC_POSITIVE"
    converter_ac = monolithic ? "CONVERTER_AC" : "REGION_6_AC"
    switch_left = monolithic ? "TOPOLOGY_LEFT" : "REGION_7_LEFT"
    switch_right = monolithic ? "TOPOLOGY_RIGHT" : "REGION_7_RIGHT"
    declarations = (
        EMTDeckRegion(
            "source_region",
            (
                "source partition_source SOURCE_NODE 10.0 0.0 0.0 0.0 120.0",
                "rl source_feed SOURCE_NODE $(terminals[1].output) 0.5 0.002",
            );
            source_identity="coupled_partition_source_region",
        ),
        EMTDeckRegion(
            "history_line_region",
            (
                "resistor line_shunt $(terminals[2].output) 0 200.0",
            );
            source_identity="coupled_partition_history_line_region",
            runtime_owners=(frequency_dependent_line_owner(
                terminals[2].input,
                terminals[2].output,
            ),),
        ),
        EMTDeckRegion(
            "measurement_transformer_region",
            (
                "resistor measurement_path $(terminals[3].input) $(terminals[3].output) 2.0",
                "resistor measurement_primary_coupling $(terminals[3].output) $measurement_primary 100.0",
                "resistor measurement_burden $measurement_secondary 0 2.0",
            );
            source_identity="coupled_partition_measurement_transformer_region",
            runtime_owners=(instrument_transformer_owner(
                measurement_primary,
                measurement_secondary,
                local_steps[3],
            ),),
        ),
        EMTDeckRegion(
            "filter_region",
            (
                "rl filter_series $(terminals[4].input) $(terminals[4].output) 1.5 5.0e-4",
                "capacitor filter_shunt $(terminals[4].output) 0 2.0e-5",
                "resistor filter_damping $(terminals[4].output) 0 150.0",
            );
            source_identity="coupled_partition_filter_region",
        ),
        EMTDeckRegion(
            "machine_region",
            (
                "resistor machine_path $(terminals[5].input) $(terminals[5].output) 2.5",
                "resistor machine_phase_a_coupling $(terminals[5].output) $machine_phase_a 500.0",
                "resistor machine_phase_b_ground $machine_phase_b 0 500.0",
                "resistor machine_phase_c_ground $machine_phase_c 0 500.0",
            );
            source_identity="coupled_partition_machine_region",
            runtime_owners=(modern_machine_owner(
                machine_phase_a,
                machine_phase_b,
                machine_phase_c,
                local_steps[5],
            ),),
        ),
        EMTDeckRegion(
            "converter_region",
            (
                "resistor converter_path $(terminals[6].input) $(terminals[6].output) 2.0",
                "resistor converter_ac_coupling $(terminals[6].output) $converter_ac 50.0",
                "resistor converter_ac_ground $converter_ac 0 100.0",
                "source converter_dc_link $converter_dc 10.0 0.0 0.0 0.0 100.0",
                "resistor converter_dc_bleed $converter_dc 0 100.0",
            );
            source_identity="coupled_partition_converter_region",
            runtime_owners=(converter_owner(
                converter_dc,
                converter_ac,
                local_steps[6],
            ),),
        ),
        EMTDeckRegion(
            "topology_region",
            (
                "resistor topology_base $(terminals[7].input) $(terminals[7].output) 6.0",
                "resistor topology_left $(terminals[7].input) $switch_left 2.0",
                "time_switch topology_transition $switch_left $switch_right 1.0 $(repr(TOPOLOGY_EVENT_TIME_S)) true 100.0 0.0",
                "resistor topology_right $switch_right $(terminals[7].output) 2.0",
                "resistor topology_reference $(terminals[7].output) 0 1.0e3",
            );
            source_identity="coupled_partition_topology_region",
        ),
        EMTDeckRegion(
            "load_region",
            (
                "resistor terminal_load $(terminals[8].input) 0 24.0",
                "capacitor terminal_capacitance $(terminals[8].input) 0 5.0e-5",
            );
            source_identity="coupled_partition_load_region",
        ),
    )
    if !monolithic
        return declarations
    end
    return (
        EMTDeckRegion(
            "monolithic_region",
            Tuple(Iterators.flatten(getfield.(declarations, :deck_lines)));
            source_identity="coupled_partition_monolithic_region",
            runtime_owners=Tuple(Iterators.flatten(getfield.(declarations, :runtime_owners))),
        ),
    )
end

const REGION_MODEL_IDENTITIES = (
    ("partition_source", "source_feed"),
    ("history_line", "line_shunt"),
    (
        "instrument_transformer_measurement",
        "measurement_burden",
        "measurement_path",
        "measurement_primary_coupling",
    ),
    ("filter_damping", "filter_series", "filter_shunt"),
    (
        "machine_path",
        "machine_phase_a_coupling",
        "machine_phase_b_ground",
        "machine_phase_c_ground",
        "modern_machine",
    ),
    (
        "converter_ac_coupling",
        "converter_ac_ground",
        "converter_dc_bleed",
        "converter_dc_link",
        "converter_path",
        "switch_detailed_converter_leg",
    ),
    (
        "topology_base",
        "topology_left",
        "topology_reference",
        "topology_right",
        "topology_transition",
    ),
    ("terminal_capacitance", "terminal_load"),
)

coupled_region_model_identities() = REGION_MODEL_IDENTITIES

function coupled_partition_study(;
    communication_step=COMMUNICATION_STEP,
    stop=STOP_TIME,
    monolithic::Bool=false,
    monolithic_step=LOCAL_STEP,
    maximum_iterations::Int=10,
    rate_ratios::Union{Nothing,NTuple{8,Int}}=nothing,
)
    if monolithic
        declarations = regional_declarations(;
            monolithic,
            local_steps=ntuple(_ -> monolithic_step, 8),
        )
        all_models = Tuple(Iterators.flatten(REGION_MODEL_IDENTITIES))
        plan = emt_partition_plan(
            (
                EMTPartitionRegion(
                    "monolithic_region",
                    all_models,
                    monolithic_step,
                ),
            ),
            ();
            start=emt_logical_time(0),
            stop,
            communication_step,
            exchange=EMTPartitionExchangePolicy(DirectCoupledExchange),
            execution_mode=MonolithicReferenceExecution,
        )
        return PartitionedDeckEMTStudy(plan, declarations)
    end
    selected_rate_ratios = something(
        rate_ratios,
        COUPLED_RATE_RATIOS,
    )
    local_steps = Tuple(
        logical_substep(communication_step, selected_rate_ratios[index]) for
        index in 1:8
    )
    declarations = regional_declarations(; local_steps)
    regions = Tuple(
        EMTPartitionRegion(
            declarations[index].identity,
            REGION_MODEL_IDENTITIES[index],
            local_steps[index],
        ) for index in 1:8
    )
    terminals = coupled_partition_terminal_map()
    ports = Tuple(
        EMTInterfacePort(
            "interface_$index",
            VoltageCurrentInterfacePort,
            declarations[index].identity,
            declarations[index + 1].identity,
            terminals[index].output,
            terminals[index + 1].input;
            voltage_base_v=120.0,
            current_base_a=10.0,
            reference_impedance_ohm=12.0,
        ) for index in 1:7
    )
    plan = emt_partition_plan(
        regions,
        ports;
        start=emt_logical_time(0),
        stop,
        communication_step,
        exchange=EMTPartitionExchangePolicy(
            IteratedWaveformExchange;
            maximum_iterations,
        ),
    )
    return PartitionedDeckEMTStudy(plan, declarations)
end

const SCALE_RATE_RATIOS = (8, 2, 8, 1, 8, 4, 2, 1)

function scale_region_declarations(; monolithic::Bool=false)
    terminals = coupled_partition_terminal_map(; monolithic)
    declarations = (
        EMTDeckRegion(
            "scale_source_region",
            (
                "source scale_source SCALE_SOURCE_NODE 10.0 0.0 0.0 0.0 120.0",
                "rl scale_feed SCALE_SOURCE_NODE $(terminals[1].output) 0.8 0.002",
            );
            source_identity="local_partition_scale_source_region",
        ),
        EMTDeckRegion(
            "scale_history_line_region",
            ("resistor scale_line_shunt $(terminals[2].output) 0 200.0",);
            source_identity="local_partition_scale_history_line_region",
            runtime_owners=(frequency_dependent_line_owner(
                terminals[2].input,
                terminals[2].output,
            ),),
        ),
        Tuple(
            EMTDeckRegion(
                "scale_passive_region_$region_index",
                (
                    "rl scale_series_$region_index $(terminals[region_index].input) $(terminals[region_index].output) $(0.4 + 0.1 * region_index) $(2.0e-4 + 5.0e-5 * region_index)",
                    "resistor scale_shunt_$region_index $(terminals[region_index].output) 0 $(100.0 + 10.0 * region_index)",
                );
                source_identity="local_partition_scale_passive_region_$region_index",
            ) for region_index in 3:7
        )...,
        EMTDeckRegion(
            "scale_load_region",
            (
                "resistor scale_load $(terminals[8].input) 0 24.0",
                "capacitor scale_capacitance $(terminals[8].input) 0 5.0e-5",
            );
            source_identity="local_partition_scale_load_region",
        ),
    )
    if !monolithic
        return declarations
    end
    return (
        EMTDeckRegion(
            "scale_monolithic_region",
            Tuple(Iterators.flatten(getfield.(declarations, :deck_lines)));
            source_identity="local_partition_scale_monolithic_region",
            runtime_owners=Tuple(Iterators.flatten(getfield.(declarations, :runtime_owners))),
        ),
    )
end

function scale_region_model_identities()
    return (
        ("scale_source", "scale_feed"),
        ("history_line", "scale_line_shunt"),
        Tuple(
            ("scale_series_$region_index", "scale_shunt_$region_index") for
            region_index in 3:7
        )...,
        ("scale_capacitance", "scale_load"),
    )
end

"""Eight-region/four-rate Semlyen-history case used for retained P2 scale evidence."""
function scale_partition_study(;
    communication_step=emt_logical_time(1 // 50_000),
    window_count::Int=2,
    monolithic::Bool=false,
    maximum_iterations::Int=4,
)
    window_count > 0 || throw(ArgumentError("scale window count must be positive"))
    stop = emt_logical_time(
        window_count * communication_step.numerator,
        communication_step.denominator,
    )
    declarations = scale_region_declarations(; monolithic)
    model_identities = scale_region_model_identities()
    if monolithic
        plan = emt_partition_plan(
            (
                EMTPartitionRegion(
                    "scale_monolithic_region",
                    Tuple(Iterators.flatten(model_identities)),
                    logical_substep(communication_step, maximum(SCALE_RATE_RATIOS)),
                ),
            ),
            ();
            start=emt_logical_time(0),
            stop,
            communication_step,
            exchange=EMTPartitionExchangePolicy(DirectCoupledExchange),
            execution_mode=MonolithicReferenceExecution,
        )
        return PartitionedDeckEMTStudy(plan, declarations)
    end
    regions = Tuple(
        EMTPartitionRegion(
            declarations[index].identity,
            model_identities[index],
            logical_substep(communication_step, SCALE_RATE_RATIOS[index]),
        ) for index in 1:8
    )
    terminals = coupled_partition_terminal_map()
    ports = Tuple(
        EMTInterfacePort(
            "scale_interface_$index",
            VoltageCurrentInterfacePort,
            declarations[index].identity,
            declarations[index + 1].identity,
            terminals[index].output,
            terminals[index + 1].input;
            voltage_base_v=120.0,
            current_base_a=10.0,
            reference_impedance_ohm=12.0,
        ) for index in 1:7
    )
    plan = emt_partition_plan(
        regions,
        ports;
        start=emt_logical_time(0),
        stop,
        communication_step,
        exchange=EMTPartitionExchangePolicy(
            IteratedWaveformExchange;
            maximum_iterations,
        ),
    )
    return PartitionedDeckEMTStudy(plan, declarations)
end

end
