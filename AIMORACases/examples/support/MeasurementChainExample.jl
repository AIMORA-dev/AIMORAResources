#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA
using LinearAlgebra
using SHA

const MEASUREMENT_EXAMPLE_SOLVER_PATH = let
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
    isempty(MEASUREMENT_EXAMPLE_SOLVER_PATH) && error(
        "the production solver is required to execute the measurement-chain examples",
    )
    pushfirst!(LOAD_PATH, MEASUREMENT_EXAMPLE_SOLVER_PATH)
    using AIMORASolvers
    AIMORA.activate_solver!(AIMORASolvers.production_backend())
end

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))

using AIMORA.Branches
using AIMORA.Nodal
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal
using .ExampleSupport

const MeasurementExamples = AIMORA.MeasurementChains
const TransformerExamples = AIMORA.TransformerApparatus
const MEASUREMENT_EXAMPLE_TIMESTEP_S = 10.0e-6
const MEASUREMENT_EXAMPLE_FREQUENCY_HZ = 50.0
const MEASUREMENT_EXAMPLE_STEP_COUNT = 1_000
const MEASUREMENT_EXAMPLE_EVENT_TIME_S = 5.0e-3
const MEASUREMENT_EXAMPLE_SOURCE_PEAK_V = 100.0
const MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S = 0.5

function measurement_example_provenance(unit::AbstractString)
    return AIMORA.StudyCore.ParameterProvenance(
        "AIMORA generic public measurement-chain products",
        unit,
        "direct synthetic SI values with explicit peak-instantaneous orientation",
        "exact synthetic input; manufacturer, calibration, field, and model-form uncertainty are unknown",
        "the exact generic fixed-step public measurement product",
        AIMORA.StudyCore.PhysicalModelParameter,
    )
end

function measurement_example_source_record(id::Symbol)
    return TransformerExamples.TransformerSourceRecord(
        id,
        bytes2hex(sha256(String(id))),
        measurement_example_provenance("SI"),
    )
end

function measurement_example_acquisition(; three_phase=false, retained_samples=1)
    return MeasurementExamples.MeasurementAcquisitionSettings(
        tick_s=MEASUREMENT_EXAMPLE_TIMESTEP_S,
        sample_period_ticks=5,
        first_sample_tick=0,
        delay_ticks=10,
        window_weights_newest_first=ones(80),
        nominal_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
        positive_sequence_threshold=three_phase ? 1.0e-6 : 0.0,
        frequency_update_separation=1,
        maximum_retained_samples=retained_samples,
    )
end

function measurement_example_filter(cutoff_hz::Real)
    pole = 2.0 * pi * Float64(cutoff_hz)
    return MeasurementExamples.AnalogMeasurementStateSpace(
        reshape([-pole], 1, 1),
        [pole],
        [1.0],
        0.0,
    )
end

function measurement_example_specification(
    id::Symbol,
    family::MeasurementExamples.MeasurementProductFamily;
    channel_names,
    quantity::Symbol,
    unit::AbstractString,
    orientation::AbstractString,
    phase_order=Symbol[],
    conditioning=MeasurementExamples.AnalogMeasurementStateSpace(),
    quantizer=MeasurementExamples.UnquantizedMeasurement(-1.0e6, 1.0e6),
    acquisition=measurement_example_acquisition(three_phase=!isempty(phase_order)),
)
    return MeasurementExamples.MeasurementChainSpecification(
        id,
        family;
        channel_names,
        quantity,
        unit,
        orientation,
        phase_order,
        conditioning,
        quantizer,
        acquisition,
        minimum_input=-1.0e6,
        maximum_input=1.0e6,
        maximum_spectral_frequency_hz=1.0e3,
        maximum_timestep_s=MEASUREMENT_EXAMPLE_TIMESTEP_S,
        provenance=measurement_example_provenance(unit),
    )
end

function measurement_example_burden()
    return MeasurementExamples.MeasurementBurden(
        series_resistance_ohm=2.0,
        series_inductance_h=1.0e-3,
        shunt_capacitance_f=0.1e-6,
        cable_resistance_ohm=0.1,
        cable_inductance_h=10.0e-6,
        cable_capacitance_f=10.0e-9,
        provenance=measurement_example_provenance("ohm,H,F"),
    )
end

function measurement_example_linear_apparatus(id::Symbol)
    connection = TransformerExamples.TransformerConnectionTopology(
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
    matrices = TransformerExamples.TransformerTerminalMatrices(
        [0.1 0.0; 0.0 0.2],
        [0.2 0.18; 0.18 0.2],
    )
    return TransformerExamples.TransformerApparatusSpecification(
        id,
        TransformerExamples.LowFrequencyTerminalTier,
        connection,
        TransformerExamples.LowFrequencyTransformerModel(matrices),
        TransformerExamples.TransformerRuntimeSettings(
            timestep_s=MEASUREMENT_EXAMPLE_TIMESTEP_S,
            initialization_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
        );
        phase_count=1,
        rated_power_va=1.0e3,
        rated_voltage_v=100.0,
        rated_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
        sources=[measurement_example_source_record(id)],
        uncertainty="exact generic public instrument-transformer inputs",
        validity_domain="one-phase generic public instrument-transformer product",
    )
end

function measurement_example_magnetic_apparatus()
    source = measurement_example_source_record(:generic_magnetic_current_transformer)
    lower_curve = TransformerExamples.TellinenLimitingCurve(
        [-1_000.0, -500.0, 0.0, 500.0, 1_000.0],
        [-1.5, -1.0, -0.2, 0.5, 1.0],
    )
    upper_curve = TransformerExamples.TellinenLimitingCurve(
        [-1_000.0, -500.0, 0.0, 500.0, 1_000.0],
        [-1.0, -0.5, 0.2, 1.0, 1.5],
    )
    material = TransformerExamples.TellinenTransformerMagneticMaterial(
        lower_curve,
        upper_curve,
        source;
        integration_field_increment_a_per_m=2.0,
    )
    graph = TransformerExamples.TransformerMagneticGraph(
        node_order=[:magnetic_node],
        branches=[
            TransformerExamples.MagneticBranchGeometry(
                :measurement_core_limb;
                length_m=0.8,
                cross_section_m2=0.01,
            ),
            TransformerExamples.MagneticBranchGeometry(
                :measurement_return_limb;
                length_m=0.8,
                cross_section_m2=0.01,
            ),
        ],
        incidence=reshape([1.0, -1.0], 1, 2),
        winding_turns=[10.0 0.0; 0.0 100.0],
        materials=[material],
    )
    connection = TransformerExamples.TransformerConnectionTopology(
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
    model = TransformerExamples.MagneticEquivalentCircuitModel(
        [0.01 0.0; 0.0 1.0],
        [1.0e-4 0.0; 0.0 1.0e-3],
        graph,
    )
    return TransformerExamples.TransformerApparatusSpecification(
        :generic_magnetic_current_transformer,
        TransformerExamples.MagneticEquivalentCircuitTier,
        connection,
        model,
        TransformerExamples.TransformerRuntimeSettings(
            timestep_s=MEASUREMENT_EXAMPLE_TIMESTEP_S,
            initialization_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
            energy_absolute_tolerance_j=1.0e-8,
            nonlinear_residual_relative_tolerance=1.0e-8,
        );
        phase_count=1,
        rated_power_va=1.0e3,
        rated_voltage_v=100.0,
        rated_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
        sources=[source],
        uncertainty="exact generic public Tellinen current-transformer inputs",
        validity_domain="one-phase generic saturating and remanent current-transformer product",
    )
end

function measurement_example_instrument_definition(case_id::Symbol)
    if case_id === :emt_measurement_saturating_ct
        family = MeasurementExamples.MagneticCurrentTransformerMeasurement
        apparatus = measurement_example_magnetic_apparatus()
        turns = (10.0, 100.0)
    elseif case_id === :emt_measurement_inductive_vt
        family = MeasurementExamples.InductiveVoltageTransformerMeasurement
        apparatus = measurement_example_linear_apparatus(:generic_inductive_voltage_transformer)
        turns = (10.0, 1.0)
    elseif case_id === :emt_measurement_cvt_transient
        family = MeasurementExamples.CouplingCapacitorVoltageTransformerMeasurement
        apparatus = measurement_example_linear_apparatus(:generic_cvt_electromagnetic_unit)
        turns = (10.0, 1.0)
    else
        family = MeasurementExamples.LinearCurrentTransformerMeasurement
        apparatus = measurement_example_linear_apparatus(:generic_linear_current_transformer)
        turns = (1.0, 10.0)
    end
    definition = MeasurementExamples.InstrumentTransformerMeasurementDefinition(
        case_id,
        family,
        apparatus;
        primary_coil_index=1,
        secondary_coil_index=2,
        primary_turns=turns[1],
        secondary_turns=turns[2],
        burden=measurement_example_burden(),
        maximum_secondary_impedance_ohm=100.0,
        secondary_output_sign=family in (
            MeasurementExamples.InductiveVoltageTransformerMeasurement,
            MeasurementExamples.CouplingCapacitorVoltageTransformerMeasurement,
        ) ? 1.0 : -1.0,
    )
    return definition
end

function measurement_example_cvt_definition()
    electromagnetic_unit = measurement_example_instrument_definition(
        :emt_measurement_cvt_transient,
    )
    high_voltage_capacitance_f = 1.0e-9
    intermediate_voltage_capacitance_f = 10.0e-9
    equivalent_capacitance_f = inv(
        inv(high_voltage_capacitance_f) + inv(intermediate_voltage_capacitance_f),
    )
    compensation_inductance_h = inv(
        (2.0 * pi * MEASUREMENT_EXAMPLE_FREQUENCY_HZ)^2 *
            equivalent_capacitance_f,
    )
    return MeasurementExamples.CouplingCapacitorVoltageTransformerDefinition(
        :generic_coupling_capacitor_voltage_transformer,
        electromagnetic_unit;
        high_voltage_capacitance_f,
        intermediate_voltage_capacitance_f,
        compensation_resistance_ohm=25.0,
        compensation_inductance_h,
        suppression_resistance_ohm=1.0e5,
        suppression_capacitance_f=1.0e-9,
        maximum_spectral_frequency_hz=500.0,
        maximum_timestep_s=MEASUREMENT_EXAMPLE_TIMESTEP_S,
        provenance=measurement_example_provenance("F,ohm,H"),
    )
end

function measurement_example_source(time_s::Real; phase_rad=0.0)
    disturbance_scale = time_s >= MEASUREMENT_EXAMPLE_EVENT_TIME_S ? 0.65 : 1.0
    return disturbance_scale * MEASUREMENT_EXAMPLE_SOURCE_PEAK_V * sin(
        2.0 * pi * MEASUREMENT_EXAMPLE_FREQUENCY_HZ * time_s + phase_rad,
    )
end

function measurement_sample_values(sample, channel_count)
    sample === nothing && return (
        held=zeros(channel_count),
        rms=zeros(channel_count),
        phasor=zeros(channel_count),
        sequence=(zero=0.0, positive=0.0, negative=0.0),
        frequency=0.0,
        valid=0.0,
    )
    rms = sample.sliding_rms === nothing ? zeros(channel_count) : sample.sliding_rms
    phasor = sample.fundamental_rms_phasors === nothing ?
        zeros(channel_count) : abs.(sample.fundamental_rms_phasors)
    sequence = sample.sequence_phasors === nothing ?
        (zero=0.0, positive=0.0, negative=0.0) : (
            zero=abs(sample.sequence_phasors.zero),
            positive=abs(sample.sequence_phasors.positive),
            negative=abs(sample.sequence_phasors.negative),
        )
    return (
        held=sample.instantaneous,
        rms,
        phasor,
        sequence,
        frequency=sample.frequency_hz === nothing ? 0.0 : sample.frequency_hz,
        valid=sample.quality === :valid ? 1.0 : 0.0,
    )
end

function transformer_measurement_stored_energy_j(runtime)
    diagnostics = TransformerExamples.transformer_apparatus_runtime_diagnostics(
        runtime.apparatus_runtime,
    )
    return sum((
        get(diagnostics, :stored_leakage_energy_j, 0.0),
        get(diagnostics, :stored_magnetic_energy_j, 0.0),
        get(diagnostics, :stored_frequency_dependent_winding_energy_j, 0.0),
        get(diagnostics, :stored_electric_energy_j, 0.0),
        get(diagnostics, :stored_energy_j, 0.0),
    ))
end

function prepare_instrument_product(case_id::Symbol)
    cvt_definition = case_id === :emt_measurement_cvt_transient ?
        measurement_example_cvt_definition() : nothing
    definition = cvt_definition === nothing ?
        measurement_example_instrument_definition(case_id) :
        cvt_definition.electromagnetic_unit
    preparation = if case_id === :emt_measurement_saturating_ct
        TransformerExamples.prepare_transformer_apparatus(
            definition.apparatus;
            initialization_mode=TransformerExamples.DeenergizedTransformerInitialization,
            initial_branch_flux_wb=[1.0e-3, 1.0e-3],
        )
    else
        TransformerExamples.prepare_transformer_apparatus(
            definition.apparatus;
            initialization_mode=TransformerExamples.DeenergizedTransformerInitialization,
        )
    end
    quantity = definition.family in (
        MeasurementExamples.LinearCurrentTransformerMeasurement,
        MeasurementExamples.MagneticCurrentTransformerMeasurement,
    ) ? :current : :voltage
    specification = measurement_example_specification(
        Symbol(case_id, :_sampled_chain),
        definition.family;
        channel_names=[Symbol(:secondary_, quantity)],
        quantity,
        unit=quantity === :current ? "A" : "V",
        orientation="positive from the secondary dotted terminal into the declared burden",
    )
    runtime = cvt_definition === nothing ?
        MeasurementExamples.instrument_transformer_measurement_runtime(
            definition,
            preparation,
            [1, 2],
            specification,
        ) : MeasurementExamples.cvt_measurement_runtime(
            cvt_definition,
            preparation,
            [1, 2],
            specification,
        )
    source_node = cvt_definition === nothing ? 1 : 3
    node_count = cvt_definition === nothing ? 2 : 4
    branch_definitions = cvt_definition === nothing ?
        MeasurementExamples.measurement_burden_branches(definition.burden, 2, 0) :
        MeasurementExamples.cvt_network_branches(
            cvt_definition;
            line_node=3,
            divider_node=4,
            electromagnetic_primary_node=1,
            secondary_node=2,
        )
    branches = AIMORA.materialize_measurement_branches(branch_definitions)
    elements = Any[
        ConductanceBranch(source_node, 0, MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S),
        CurrentInjection(
            source_node,
            time_s -> MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S *
                measurement_example_source(time_s),
        ),
    ]
    append!(elements, branches)
    linear_system = NodalSystem(node_count, elements)
    scales = NonlinearNetworkScales(
        fill(MEASUREMENT_EXAMPLE_SOURCE_PEAK_V, node_count),
        fill(MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S *
            MEASUREMENT_EXAMPLE_SOURCE_PEAK_V, node_count),
        Float64[],
        Float64[],
    )
    system = NonlinearNodalSystem(linear_system, [runtime]; scales)
    return (; case_id, definition, cvt_definition, runtime, branches, system)
end

function advance_instrument_product!(product, step_index::Int)
    time_s = step_index * MEASUREMENT_EXAMPLE_TIMESTEP_S
    result = advance_nonlinear_step!(
        product.system,
        time_s,
        MEASUREMENT_EXAMPLE_TIMESTEP_S,
    )
    result.accepted || error(
        "public measurement network failed at step $(step_index): $(result.failure)",
    )
    output = MeasurementExamples.instrument_transformer_measurement_output(
        product.runtime,
    )
    sample = output.latest_sample
    values = measurement_sample_values(sample, 1)
    voltage = nonlinear_linear_system(product.system).v
    stored_energy_j = transformer_measurement_stored_energy_j(product.runtime)
    if product.cvt_definition !== nothing
        compensation = product.branches[3]
        cvt_output = MeasurementExamples.cvt_measurement_output(
            product.cvt_definition,
            product.runtime;
            line_voltage_v=voltage[3],
            divider_voltage_v=voltage[4],
            electromagnetic_primary_voltage_v=voltage[1],
            compensation_current_a=compensation.i_last,
        )
        stored_energy_j = cvt_output.stored_energy_j
    end
    row = (
        time_s,
        source_value=voltage[product.cvt_definition === nothing ? 1 : 3],
        secondary_value=output.family in (
            MeasurementExamples.LinearCurrentTransformerMeasurement,
            MeasurementExamples.MagneticCurrentTransformerMeasurement,
        ) ? output.secondary_current_a : output.secondary_voltage_v,
        held_value=values.held[1],
        rms_value=values.rms[1],
        phasor_magnitude=values.phasor[1],
        valid=values.valid,
        stored_energy_j,
        kcl_residual_a=result.diagnostics.maximum_kcl_residual_a,
    )
    return row, copy(product.runtime.released_samples)
end

function execute_instrument_product(case_id::Symbol)
    product = prepare_instrument_product(case_id)
    split_step = MEASUREMENT_EXAMPLE_STEP_COUNT ÷ 2
    rows = NamedTuple[]
    released_samples = MeasurementExamples.MeasurementSample[]
    checkpoint = nothing
    for step_index in 1:MEASUREMENT_EXAMPLE_STEP_COUNT
        row, released = advance_instrument_product!(product, step_index)
        push!(rows, row)
        append!(released_samples, released)
        step_index == split_step &&
            (checkpoint = nonlinear_nodal_checkpoint(product.system))
    end
    checkpoint === nothing && error("instrument-product checkpoint was not captured")
    final_signature = MeasurementExamples.instrument_transformer_measurement_signature(
        product.runtime,
    )
    restore_nonlinear_nodal_checkpoint!(product.system, checkpoint)
    for step_index in (split_step + 1):MEASUREMENT_EXAMPLE_STEP_COUNT
        advance_instrument_product!(product, step_index)
    end
    replay_signature = MeasurementExamples.instrument_transformer_measurement_signature(
        product.runtime,
    )
    final_signature == replay_signature || error(
        "instrument-product checkpoint replay was not exact",
    )
    return (; product..., rows, released_samples, restart_exact=true, final_signature)
end

function measurement_example_electronic_definition(case_id::Symbol)
    current_sensor = case_id === :emt_measurement_electronic_current
    family = current_sensor ?
        MeasurementExamples.ElectronicCurrentSensorMeasurement :
        MeasurementExamples.ElectronicVoltageSensorMeasurement
    coupling = current_sensor ?
        MeasurementExamples.CurrentSeriesElectronicInsertion :
        MeasurementExamples.VoltageShuntElectronicLoading
    return MeasurementExamples.ElectronicSensorDefinition(
        case_id,
        family;
        coupling,
        transducer=measurement_example_filter(500.0),
        input_scale=current_sensor ? 1.0 : 0.01,
        input_offset=0.0,
        minimum_observed_input=-1.0e4,
        maximum_observed_input=1.0e4,
        loading_resistance_ohm=current_sensor ? 0.02 : 1.0e6,
        loading_inductance_h=current_sensor ? 10.0e-6 : 0.0,
        loading_capacitance_f=current_sensor ? 0.0 : 10.0e-12,
        provenance=measurement_example_provenance(current_sensor ? "A" : "V"),
    )
end

function prepare_electronic_product(case_id::Symbol)
    definition = measurement_example_electronic_definition(case_id)
    current_sensor = case_id === :emt_measurement_electronic_current
    specification = measurement_example_specification(
        Symbol(case_id, :_sampled_chain),
        definition.family;
        channel_names=[current_sensor ? :measured_current : :measured_voltage],
        quantity=current_sensor ? :current : :voltage,
        unit=current_sensor ? "A" : "V",
        orientation="positive from the declared primary terminal toward reference",
        conditioning=definition.transducer,
    )
    runtime = MeasurementExamples.electronic_sensor_runtime(
        definition,
        specification;
        initial_observed_input=0.0,
    )
    loading_definitions = MeasurementExamples.electronic_sensor_loading_branches(
        definition,
        1,
        current_sensor ? 2 : 0,
    )
    loading_branches = AIMORA.materialize_measurement_branches(loading_definitions)
    elements = Any[
        ConductanceBranch(1, 0, MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S),
        CurrentInjection(
            1,
            time_s -> MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S *
                measurement_example_source(time_s),
        ),
    ]
    append!(elements, loading_branches)
    current_sensor && push!(elements, ConductanceBranch(2, 0, 0.1))
    system = NodalSystem(current_sensor ? 2 : 1, elements)
    return (; case_id, definition, runtime, loading_branches, system, current_sensor)
end

function advance_electronic_product!(product, step_index::Int)
    time_s = step_index * MEASUREMENT_EXAMPLE_TIMESTEP_S
    solve_algebraic_state!(product.system, time_s, MEASUREMENT_EXAMPLE_TIMESTEP_S)
    accept_algebraic_state!(product.system, MEASUREMENT_EXAMPLE_TIMESTEP_S)
    observed = product.current_sensor ?
        first(product.loading_branches).i_last : product.system.v[1]
    MeasurementExamples.prepare_electronic_sensor_step!(
        product.runtime,
        observed,
        MEASUREMENT_EXAMPLE_TIMESTEP_S,
    )
    released = MeasurementExamples.accept_electronic_sensor_step!(
        product.runtime,
        step_index,
    )
    output = MeasurementExamples.electronic_sensor_output(product.runtime)
    values = measurement_sample_values(output.latest_sample, 1)
    row = (
        time_s,
        source_value=product.system.v[1],
        observed_value=observed,
        transducer_value=output.conditioned_output,
        held_value=values.held[1],
        rms_value=values.rms[1],
        phasor_magnitude=values.phasor[1],
        valid=values.valid,
    )
    return row, released
end

function execute_electronic_product(case_id::Symbol)
    product = prepare_electronic_product(case_id)
    split_step = MEASUREMENT_EXAMPLE_STEP_COUNT ÷ 2
    rows = NamedTuple[]
    released_samples = MeasurementExamples.MeasurementSample[]
    snapshot = nothing
    for step_index in 1:MEASUREMENT_EXAMPLE_STEP_COUNT
        row, released = advance_electronic_product!(product, step_index)
        push!(rows, row)
        append!(released_samples, released)
        step_index == split_step &&
            (snapshot = MeasurementExamples.electronic_sensor_snapshot(product.runtime))
    end
    snapshot === nothing && error("electronic-sensor snapshot was not captured")
    final_signature = MeasurementExamples.electronic_sensor_signature(product.runtime)
    replay = prepare_electronic_product(case_id)
    for step_index in 1:split_step
        advance_electronic_product!(replay, step_index)
    end
    MeasurementExamples.restore_electronic_sensor_snapshot!(replay.runtime, snapshot)
    for step_index in (split_step + 1):MEASUREMENT_EXAMPLE_STEP_COUNT
        advance_electronic_product!(replay, step_index)
    end
    MeasurementExamples.electronic_sensor_signature(replay.runtime) == final_signature ||
        error("electronic-sensor snapshot replay was not exact")
    return (; product..., rows, released_samples, restart_exact=true, final_signature)
end

function prepare_three_phase_product()
    acquisition = measurement_example_acquisition(
        three_phase=true,
        retained_samples=1,
    )
    quantizer = MeasurementExamples.UniformMeasurementQuantizer(
        lower_limit=-400.0,
        upper_limit=400.0,
        engineering_step=0.02,
        engineering_offset=0.0,
        minimum_code=-20_000,
        maximum_code=20_000,
        tie_rule=MeasurementExamples.MeasurementTiesToEven,
    )
    specification = measurement_example_specification(
        :generic_three_phase_sampled_measurement,
        MeasurementExamples.ThreePhaseSampledMeasurement;
        channel_names=[:phase_a_voltage, :phase_b_voltage, :phase_c_voltage],
        quantity=:voltage,
        unit="V",
        orientation="phase-to-reference positive abc order",
        phase_order=[:a, :b, :c],
        conditioning=measurement_example_filter(1.0e3),
        quantizer,
        acquisition,
    )
    runtime = MeasurementExamples.MeasurementChainRuntime(specification)
    MeasurementExamples.initialize_measurement_chain_at_tick!(runtime, 0)
    elements = Any[]
    for (node, phase_rad) in enumerate((0.0, -2.0 * pi / 3.0, 2.0 * pi / 3.0))
        push!(elements, ConductanceBranch(node, 0, MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S))
        push!(elements, CurrentInjection(
            node,
            let phase = phase_rad
                time_s -> MEASUREMENT_EXAMPLE_SOURCE_CONDUCTANCE_S *
                    measurement_example_source(time_s; phase_rad=phase)
            end,
        ))
        push!(elements, ConductanceBranch(node, 0, 0.01))
    end
    return (; runtime, system=NodalSystem(3, elements))
end

function advance_three_phase_product!(product, step_index::Int)
    time_s = step_index * MEASUREMENT_EXAMPLE_TIMESTEP_S
    solve_algebraic_state!(product.system, time_s, MEASUREMENT_EXAMPLE_TIMESTEP_S)
    accept_algebraic_state!(product.system, MEASUREMENT_EXAMPLE_TIMESTEP_S)
    MeasurementExamples.prepare_measurement_analog_step!(
        product.runtime,
        product.system.v,
        MEASUREMENT_EXAMPLE_TIMESTEP_S,
    )
    released = MeasurementExamples.accept_measurement_analog_step!(
        product.runtime,
        step_index,
    )
    latest = isempty(product.runtime.samples) ? nothing : last(product.runtime.samples)
    values = measurement_sample_values(latest, 3)
    row = (
        time_s,
        phase_a_input_v=product.system.v[1],
        phase_b_input_v=product.system.v[2],
        phase_c_input_v=product.system.v[3],
        phase_a_held_v=values.held[1],
        phase_b_held_v=values.held[2],
        phase_c_held_v=values.held[3],
        positive_sequence_v=values.sequence.positive,
        negative_sequence_v=values.sequence.negative,
        zero_sequence_v=values.sequence.zero,
        frequency_hz=values.frequency,
        valid=values.valid,
    )
    return row, released
end

function execute_three_phase_product()
    product = prepare_three_phase_product()
    split_step = MEASUREMENT_EXAMPLE_STEP_COUNT ÷ 2
    rows = NamedTuple[]
    released_samples = MeasurementExamples.MeasurementSample[]
    snapshot = nothing
    for step_index in 1:MEASUREMENT_EXAMPLE_STEP_COUNT
        row, released = advance_three_phase_product!(product, step_index)
        push!(rows, row)
        append!(released_samples, released)
        step_index == split_step &&
            (snapshot = MeasurementExamples.measurement_chain_snapshot(product.runtime))
    end
    snapshot === nothing && error("three-phase measurement snapshot was not captured")
    final_signature = MeasurementExamples.measurement_chain_result_signature(product.runtime)
    replay = prepare_three_phase_product()
    for step_index in 1:split_step
        advance_three_phase_product!(replay, step_index)
    end
    MeasurementExamples.restore_measurement_chain_snapshot!(replay.runtime, snapshot)
    for step_index in (split_step + 1):MEASUREMENT_EXAMPLE_STEP_COUNT
        advance_three_phase_product!(replay, step_index)
    end
    MeasurementExamples.measurement_chain_result_signature(replay.runtime) ==
        final_signature || error("three-phase measurement snapshot replay was not exact")
    return (; product..., rows, released_samples, restart_exact=true, final_signature)
end

function write_measurement_comtrade(output_dir, case_id, samples)
    isempty(samples) && error("measurement public product produced no released samples")
    channel_count = length(first(samples).instantaneous)
    current_product = case_id in (
        :emt_measurement_linear_ct,
        :emt_measurement_saturating_ct,
        :emt_measurement_electronic_current,
    )
    analog_channels = [
        MeasurementExamples.ComtradeAnalogChannel(
            channel,
            "measurement_channel_$(channel)";
            phase=channel_count == 3 ? string(Char('A' + channel - 1)) : "",
            circuit="generic_measurement_product",
            unit=current_product ? "A" : "V",
            scale=0.02,
            minimum_raw=-100_000,
            maximum_raw=100_000,
            primary_ratio=1.0,
            secondary_ratio=1.0,
            primary_secondary=:secondary,
        ) for channel in 1:channel_count
    ]
    digital_channels = [
        MeasurementExamples.ComtradeDigitalChannel(
            1,
            "measurement_valid";
            circuit="generic_measurement_product",
            normal_state=false,
        ),
    ]
    configuration = MeasurementExamples.ComtradeConfiguration(
        "AIMORA synthetic measurement station",
        "AIMORA generic recorder",
        MeasurementExamples.Comtrade2013;
        analog_channels,
        digital_channels,
        nominal_frequency_hz=MEASUREMENT_EXAMPLE_FREQUENCY_HZ,
        sample_rates=[MeasurementExamples.ComtradeSampleRate(
            inv(MEASUREMENT_EXAMPLE_TIMESTEP_S * 5),
            length(samples),
        )],
        start_timestamp=MeasurementExamples.ComtradeTimestamp(2026, 8, 15, 0, 0, 0),
        trigger_timestamp=MeasurementExamples.ComtradeTimestamp(
            2026,
            8,
            15,
            0,
            0,
            0,
            round(Int, MEASUREMENT_EXAMPLE_EVENT_TIME_S * 1.0e9),
        ),
        encoding=MeasurementExamples.ComtradeBinary32,
        time_multiplier=1.0,
    )
    raw = Matrix{Float64}(undef, length(samples), channel_count)
    digital = falses(length(samples), 1)
    for (row, sample) in enumerate(samples)
        raw[row, :] .= round.(sample.instantaneous ./ 0.02)
        digital[row, 1] = sample.quality === :valid
    end
    record = MeasurementExamples.ComtradeRecord(
        configuration,
        1:length(samples),
        round.(Int, getfield.(samples, :source_time_s) .* 1.0e6),
        raw,
        digital,
    )
    serialized = MeasurementExamples.write_comtrade_record(
        record;
        encoding=MeasurementExamples.ComtradeBinary32,
    )
    configuration_path = joinpath(output_dir, "measurement_record.cfg")
    data_path = joinpath(output_dir, "measurement_record.dat")
    write(configuration_path, serialized.configuration_text)
    write(data_path, serialized.data_bytes)
    parsed = MeasurementExamples.read_comtrade_files(configuration_path, data_path)
    parsed.sample_numbers == record.sample_numbers || error(
        "public COMTRADE file round trip changed sample identity",
    )
    return (; configuration_path, data_path, signature=serialized.deterministic_signature_sha256)
end

function write_measurement_product(output_dir::AbstractString, case_id::Symbol, result)
    mkpath(output_dir)
    times = getfield.(result.rows, :time_s)
    if case_id === :emt_measurement_three_phase_chain
        waveform_series = Pair{String,Vector{Float64}}[
            "phase_a_input_v" => getfield.(result.rows, :phase_a_input_v),
            "phase_b_input_v" => getfield.(result.rows, :phase_b_input_v),
            "phase_c_input_v" => getfield.(result.rows, :phase_c_input_v),
            "phase_a_held_v" => getfield.(result.rows, :phase_a_held_v),
        ]
        diagnostic_series = Pair{String,Vector{Float64}}[
            "positive_sequence_v" => getfield.(result.rows, :positive_sequence_v),
            "negative_sequence_v" => getfield.(result.rows, :negative_sequence_v),
            "frequency_hz" => getfield.(result.rows, :frequency_hz),
            "valid" => getfield.(result.rows, :valid),
        ]
    elseif hasproperty(first(result.rows), :transducer_value)
        waveform_series = Pair{String,Vector{Float64}}[
            "source_value" => getfield.(result.rows, :source_value),
            "observed_value" => getfield.(result.rows, :observed_value),
            "transducer_value" => getfield.(result.rows, :transducer_value),
            "held_value" => getfield.(result.rows, :held_value),
        ]
        diagnostic_series = Pair{String,Vector{Float64}}[
            "rms_value" => getfield.(result.rows, :rms_value),
            "phasor_magnitude" => getfield.(result.rows, :phasor_magnitude),
            "valid" => getfield.(result.rows, :valid),
        ]
    else
        waveform_series = Pair{String,Vector{Float64}}[
            "source_value" => getfield.(result.rows, :source_value),
            "secondary_value" => getfield.(result.rows, :secondary_value),
            "held_value" => getfield.(result.rows, :held_value),
        ]
        diagnostic_series = Pair{String,Vector{Float64}}[
            "rms_value" => getfield.(result.rows, :rms_value),
            "stored_energy_j" => getfield.(result.rows, :stored_energy_j),
            "kcl_residual_a" => getfield.(result.rows, :kcl_residual_a),
            "valid" => getfield.(result.rows, :valid),
        ]
    end
    write_series_csv(
        joinpath(output_dir, "measurement_waveforms.csv"),
        "time_s",
        times,
        waveform_series,
    )
    write_series_csv(
        joinpath(output_dir, "measurement_diagnostics.csv"),
        "time_s",
        times,
        diagnostic_series,
    )
    write_waveform_svg(
        joinpath(output_dir, "measurement_waveforms.svg"),
        times,
        waveform_series;
        title="$(case_id): physical and sampled response",
        y_label="declared SI value",
    )
    write_waveform_svg(
        joinpath(output_dir, "measurement_diagnostics.svg"),
        times,
        diagnostic_series;
        title="$(case_id): causal estimates and diagnostics",
        y_label="declared SI value",
    )
    comtrade = write_measurement_comtrade(output_dir, case_id, result.released_samples)
    write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "$(case_id) public measurement product",
        (
            accepted_steps=MEASUREMENT_EXAMPLE_STEP_COUNT,
            released_samples=length(result.released_samples),
            restart_exact=result.restart_exact,
            result_signature_sha256=result.final_signature,
            comtrade_signature_sha256=comtrade.signature,
            event_time_s=MEASUREMENT_EXAMPLE_EVENT_TIME_S,
            limitation="Generic synthetic fixed-step product; no vendor, calibration, protected-standard, field-recording, protection, ATP/PSCAD, HIL, or certification equivalence.",
        ),
    )
    return result
end

function run_measurement_product(output_dir::AbstractString, case_id::Symbol)
    result = if case_id in (
        :emt_measurement_linear_ct,
        :emt_measurement_saturating_ct,
        :emt_measurement_inductive_vt,
        :emt_measurement_cvt_transient,
    )
        execute_instrument_product(case_id)
    elseif case_id in (
        :emt_measurement_electronic_current,
        :emt_measurement_electronic_voltage,
    )
        execute_electronic_product(case_id)
    elseif case_id === :emt_measurement_three_phase_chain
        execute_three_phase_product()
    else
        throw(ArgumentError("unknown public measurement product $(case_id)"))
    end
    return write_measurement_product(output_dir, case_id, result)
end
