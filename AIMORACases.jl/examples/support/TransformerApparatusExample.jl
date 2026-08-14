#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA
using LinearAlgebra
using Printf

const TRANSFORMER_EXAMPLE_SOLVER_PATH = let
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
    isempty(TRANSFORMER_EXAMPLE_SOLVER_PATH) && error(
        "the production solver is required to execute the transformer apparatus examples",
    )
    pushfirst!(LOAD_PATH, TRANSFORMER_EXAMPLE_SOLVER_PATH)
    using AIMORASolvers
    AIMORA.activate_solver!(AIMORASolvers.production_backend())
end

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))

using AIMORA.Branches
using AIMORA.Nodal
using AIMORA.NonlinearNetwork
using AIMORA.NonlinearNodal
using .ExampleSupport

const TransformerExamples = AIMORA.TransformerApparatus
const TRANSFORMER_EXAMPLE_TIMESTEP_S = 10.0e-6
const TRANSFORMER_EXAMPLE_FREQUENCY_HZ = 100.0
const TRANSFORMER_EXAMPLE_STEP_COUNT = 1_000
const TRANSFORMER_EXAMPLE_EVENT_TIME_S = 5.0e-3
const TRANSFORMER_EXAMPLE_SOURCE_CONDUCTANCE_S = 0.5
const TRANSFORMER_EXAMPLE_SOURCE_PEAK_V = 100.0
const TRANSFORMER_EXAMPLE_FAULT_CONDUCTANCE_S = 0.01

function transformer_example_source()
    provenance = AIMORA.StudyCore.ParameterProvenance(
        "AIMORA generic public transformer and reactor products",
        "SI",
        "direct synthetic values and explicitly declared deterministic derivations",
        "exact synthetic values; measurement and manufacturer uncertainty are unknown",
        "redistributable generic transformer apparatus examples",
        AIMORA.StudyCore.PhysicalModelParameter,
    )
    return TransformerExamples.TransformerSourceRecord(
        :generic_public_transformer_apparatus,
        repeat("4", 64),
        provenance,
    )
end

function terminal_connection(terminal_count::Int; label::String)
    terminal_count >= 2 || throw(ArgumentError(
        "a transformer terminal product requires at least two terminals",
    ))
    winding_order = [Symbol(:winding_, index) for index in 1:terminal_count]
    return TransformerExamples.TransformerConnectionTopology(
        node_order=[Symbol(:terminal_, index) for index in 1:terminal_count],
        coil_order=[Symbol(:coil_, index) for index in 1:terminal_count],
        winding_order=winding_order,
        phase_order=[:phase_a],
        coil_winding=winding_order,
        coil_phase=fill(:phase_a, terminal_count),
        incidence=Matrix{Float64}(I, terminal_count, terminal_count),
        vector_group=label,
        clock_number=0,
        phase_shift_rad=0.0,
    )
end

function winding_connection(winding_count::Int; label::String)
    winding_count >= 2 || throw(ArgumentError(
        "a sectioned transformer product requires at least two windings",
    ))
    winding_order = [Symbol(:winding_, index) for index in 1:winding_count]
    node_order = Symbol[]
    incidence = zeros(2 * winding_count, winding_count)
    for winding_index in 1:winding_count
        push!(node_order, Symbol(:winding_, winding_index, :_start))
        push!(node_order, Symbol(:winding_, winding_index, :_end))
        incidence[2 * winding_index - 1, winding_index] = 1.0
        incidence[2 * winding_index, winding_index] = -1.0
    end
    return TransformerExamples.TransformerConnectionTopology(
        node_order=node_order,
        coil_order=[Symbol(:coil_, index) for index in 1:winding_count],
        winding_order=winding_order,
        phase_order=[:phase_a],
        coil_winding=winding_order,
        coil_phase=fill(:phase_a, winding_count),
        incidence=incidence,
        vector_group=label,
        clock_number=0,
        phase_shift_rad=0.0,
    )
end

function three_phase_multiwinding_connection(winding_count::Int; label::String)
    winding_count >= 2 || throw(ArgumentError(
        "a three-phase transformer product requires at least two windings",
    ))
    phases = [:phase_a, :phase_b, :phase_c]
    winding_order = [Symbol(:winding_, index) for index in 1:winding_count]
    coil_winding = Symbol[]
    coil_phase = Symbol[]
    for winding in winding_order, phase in phases
        push!(coil_winding, winding)
        push!(coil_phase, phase)
    end
    coil_count = length(coil_winding)
    return TransformerExamples.TransformerConnectionTopology(
        node_order=[Symbol(:phase_terminal_, index) for index in 1:coil_count],
        node_phase=copy(coil_phase),
        coil_order=[Symbol(:phase_coil_, index) for index in 1:coil_count],
        winding_order=winding_order,
        phase_order=phases,
        coil_winding=coil_winding,
        coil_phase=coil_phase,
        incidence=Matrix{Float64}(I, coil_count, coil_count),
        vector_group=label,
        clock_number=0,
        phase_shift_rad=0.0,
    )
end

function coupled_positive_matrix(count::Int, diagonal_value::Float64, coupling_value::Float64)
    matrix = fill(coupling_value, count, count)
    for index in 1:count
        matrix[index, index] = diagonal_value
    end
    return matrix
end

function public_piecewise_magnetic_graph(source; winding_count::Int=2)
    material = TransformerExamples.PiecewiseLinearTransformerMagneticMaterial(
        [0.0, 0.5, 1.5, 2.0],
        [0.0, 100.0, 2_000.0, 10_000.0],
        source,
    )
    winding_turns = zeros(2, winding_count)
    for winding_index in 1:winding_count
        winding_turns[mod1(winding_index, 2), winding_index] =
            winding_index == 1 ? 100.0 : 50.0
    end
    return TransformerExamples.TransformerMagneticGraph(
        node_order=[:magnetic_junction],
        branches=[
            TransformerExamples.MagneticBranchGeometry(
                :core_limb;
                length_m=0.8,
                cross_section_m2=0.01,
            ),
            TransformerExamples.MagneticBranchGeometry(
                :return_limb;
                length_m=0.8,
                cross_section_m2=0.01,
            ),
        ],
        incidence=reshape([1.0, -1.0], 1, 2),
        winding_turns=winding_turns,
        materials=[material],
    )
end

function public_terminal_matrices(count::Int)
    return TransformerExamples.TransformerTerminalMatrices(
        coupled_positive_matrix(count, 0.4, 0.01),
        coupled_positive_matrix(count, 8.0e-3, 0.2e-3);
        capacitance_f=Diagonal(fill(1.0e-7, count)),
        conductance_s=Diagonal(fill(1.0e-5, count)),
    )
end

function wideband_model(port_count::Int, state_count::Int)
    state_matrix = -Diagonal(range(800.0, 1_200.0; length=state_count))
    input_matrix = zeros(state_count, port_count)
    for state_index in 1:state_count
        input_matrix[state_index, mod1(state_index, port_count)] =
            inv(sqrt(ceil(state_count / port_count)))
    end
    return TransformerExamples.WidebandTransformerModel(
        state_matrix,
        input_matrix,
        transpose(input_matrix),
        0.02 .* Matrix{Float64}(I, port_count, port_count);
        storage_matrix_j=Matrix{Float64}(I, state_count, state_count),
        port_order=[Symbol(:terminal_, index) for index in 1:port_count],
        frequency_band_hz=(10.0, 40_000.0),
        continuous_passivity_margin_s=0.02,
        enforcement_perturbation_relative=0.0,
        source_response_sha256=repeat("5", 64),
    )
end

function grey_box_model(node_count::Int)
    branches = [
        TransformerExamples.TransformerLadderBranch(
            Symbol(:ladder_branch_, index),
            index,
            index + 1;
            resistance_ohm=0.02 + 1.0e-4 * index,
            inductance_h=0.2e-3 + 1.0e-6 * index,
        ) for index in 1:(node_count - 1)
    ]
    return TransformerExamples.GreyBoxTransformerModel(
        node_order=[Symbol(:ladder_node_, index) for index in 1:node_count],
        terminal_node_indices=[1, node_count],
        branches=branches,
        capacitance_f=Diagonal(fill(2.0e-9, node_count)),
        conductance_s=Diagonal(fill(1.0e-7, node_count)),
        source_response_sha256=repeat("6", 64),
        identification_residual_relative=1.0e-4,
        parameter_nonuniqueness=
            "generic physical ladder; terminal data alone does not identify one unique interior",
    )
end

function white_box_model(winding_count::Int, section_count::Int)
    resistance = coupled_positive_matrix(winding_count, 0.2, 0.01)
    inductance = coupled_positive_matrix(winding_count, 2.0e-3, 0.1e-3)
    conductance = coupled_positive_matrix(winding_count, 1.0e-7, 0.02e-7)
    capacitance = coupled_positive_matrix(winding_count, 2.0e-9, 0.1e-9)
    return TransformerExamples.WhiteBoxTransformerModel(
        winding_order=[Symbol(:winding_, index) for index in 1:winding_count],
        section_count_per_winding=fill(section_count, winding_count),
        section_length_m=fill(0.1, section_count),
        series_resistance_ohm_per_m=fill(resistance, section_count),
        series_inductance_h_per_m=fill(inductance, section_count),
        shunt_conductance_s_per_m=fill(conductance, section_count),
        shunt_capacitance_f_per_m=fill(capacitance, section_count),
        geometry_sha256=repeat("7", 64),
        frequency_band_hz=(10.0, 40_000.0),
        section_refinement_residual_relative=1.0e-3,
    )
end

function transformer_product(case_id::Symbol)
    source = transformer_example_source()
    if case_id === :emt_transformer_low_frequency
        connection = terminal_connection(2; label="generic single-phase low-frequency")
        tier = TransformerExamples.LowFrequencyTerminalTier
        model = TransformerExamples.LowFrequencyTransformerModel(public_terminal_matrices(2))
        description = "coupled low-frequency terminal matrix"
    elseif case_id === :emt_transformer_bctran
        connection = three_phase_multiwinding_connection(
            3;
            label="generic three-phase three-winding BCTRAN",
        )
        tier = TransformerExamples.BCTRANTerminalTier
        model = TransformerExamples.BCTRANTransformerModel(
            public_terminal_matrices(9);
            positive_pair_reconstruction_residual=0.0,
            zero_pair_reconstruction_residual=0.0,
            inverse_reconstruction_residual=0.0,
        )
        description = "three-phase three-winding BCTRAN-style terminal matrix"
    elseif case_id === :emt_transformer_hybrid
        connection = terminal_connection(2; label="generic hybrid leakage and nonlinear core")
        tier = TransformerExamples.HybridTransformerTier
        model = TransformerExamples.HybridTransformerModel(
            public_terminal_matrices(2),
            public_piecewise_magnetic_graph(source),
        )
        description = "hybrid leakage, capacitance, and nonlinear magnetic graph"
    elseif case_id === :emt_transformer_magnetic_equivalent
        connection = terminal_connection(2; label="generic magnetic equivalent circuit")
        tier = TransformerExamples.MagneticEquivalentCircuitTier
        matrices = public_terminal_matrices(2)
        model = TransformerExamples.MagneticEquivalentCircuitModel(
            matrices.resistance_ohm,
            matrices.inductance_h,
            public_piecewise_magnetic_graph(source);
            terminal_capacitance_f=matrices.capacitance_f,
            terminal_conductance_s=matrices.conductance_s,
        )
        description = "unified nonlinear magnetic-equivalent circuit"
    elseif case_id === :emt_transformer_wideband_black_box
        connection = terminal_connection(12; label="generic passive twelve-port black box")
        tier = TransformerExamples.WidebandBlackBoxTier
        model = wideband_model(12, 24)
        description = "passive twelve-port wideband black-box realization"
    elseif case_id === :emt_transformer_grey_box
        connection = terminal_connection(2; label="generic thirty-two-node grey box")
        tier = TransformerExamples.GreyBoxLadderTier
        model = grey_box_model(32)
        description = "physical thirty-two-node grey-box ladder"
    elseif case_id === :emt_transformer_white_box
        connection = winding_connection(4; label="generic four-winding section model")
        tier = TransformerExamples.WhiteBoxWindingTier
        model = white_box_model(4, 8)
        description = "geometry-owned four-winding eight-section white box"
    else
        throw(ArgumentError("unknown public transformer product $(case_id)"))
    end
    settings = TransformerExamples.TransformerRuntimeSettings(
        timestep_s=TRANSFORMER_EXAMPLE_TIMESTEP_S,
        initialization_frequency_hz=TRANSFORMER_EXAMPLE_FREQUENCY_HZ,
        kcl_absolute_tolerance_a=1.0e-7,
        magnetic_continuity_absolute_tolerance_wb=1.0e-10,
        energy_absolute_tolerance_j=1.0e-7,
    )
    specification = TransformerExamples.TransformerApparatusSpecification(
        case_id,
        tier,
        connection,
        model,
        settings;
        phase_count=case_id === :emt_transformer_bctran ? 3 : 1,
        rated_power_va=10.0e6,
        rated_voltage_v=33.0e3,
        rated_frequency_hz=TRANSFORMER_EXAMPLE_FREQUENCY_HZ,
        sources=[source],
        uncertainty=
            "exact generic inputs; measurement, manufacturer, field, and model-form uncertainty are unknown",
        validity_domain=
            "this redistributable generic $(description) product at its exact topology, matrices, source, timestep, event, and 100 Hz execution",
    )
    preparation = TransformerExamples.prepare_transformer_apparatus(specification)
    runtime = TransformerExamples.transformer_apparatus_runtime(
        preparation,
        collect(1:length(connection.node_order)),
    )
    TransformerExamples.queue_transformer_apparatus_event!(
        runtime,
        TransformerExamples.TransformerApparatusEventCommand(
            :terminal_fault_application,
            TransformerExamples.TransformerTerminalFaultApplyEvent,
            TRANSFORMER_EXAMPLE_EVENT_TIME_S;
            target_indices=[1],
            conductance_s=TRANSFORMER_EXAMPLE_FAULT_CONDUCTANCE_S,
        ),
    )
    return (; case_id, tier, description, specification, preparation, runtime)
end

function transformer_product_network(product)
    terminal_count = length(product.runtime.terminal_nodes)
    elements = Any[]
    phase_angles = range(0.0, 2.0 * pi; length=terminal_count + 1)[1:end-1]
    for terminal_index in 1:terminal_count
        push!(elements, ConductanceBranch(
            terminal_index,
            0,
            TRANSFORMER_EXAMPLE_SOURCE_CONDUCTANCE_S,
        ))
        angle = phase_angles[terminal_index]
        push!(elements, CurrentInjection(
            terminal_index,
            let source_angle = angle
                time_s -> TRANSFORMER_EXAMPLE_SOURCE_CONDUCTANCE_S *
                    TRANSFORMER_EXAMPLE_SOURCE_PEAK_V * sin(
                        2.0 * pi * TRANSFORMER_EXAMPLE_FREQUENCY_HZ * time_s +
                        source_angle,
                    )
            end,
        ))
    end
    linear_system = NodalSystem(terminal_count, elements)
    scales = NonlinearNetworkScales(
        fill(TRANSFORMER_EXAMPLE_SOURCE_PEAK_V, terminal_count),
        fill(
            TRANSFORMER_EXAMPLE_SOURCE_CONDUCTANCE_S *
                TRANSFORMER_EXAMPLE_SOURCE_PEAK_V,
            terminal_count,
        ),
        Float64[],
        Float64[],
    )
    system = NonlinearNodalSystem(linear_system, [product.runtime]; scales)
    return (; product..., system)
end

function accepted_transformer_sample(runtime, result)
    state = runtime.accepted_state
    return (
        time_s=state.accepted_time_s,
        terminal_voltage_v=state.terminal_voltage_v[1],
        terminal_current_a=state.terminal_current_a[1],
        terminal_power_w=state.terminal_power_w,
        supplied_energy_j=state.supplied_energy_j,
        maximum_kcl_residual_a=result.diagnostics.maximum_kcl_residual_a,
    )
end

function advance_transformer_product_step!(execution, step_index::Int)
    time_s = step_index * TRANSFORMER_EXAMPLE_TIMESTEP_S
    result = advance_nonlinear_step!(
        execution.system,
        time_s,
        TRANSFORMER_EXAMPLE_TIMESTEP_S,
    )
    result.accepted || error(
        "public transformer network failed at step $(step_index): $(result.failure)",
    )
    return accepted_transformer_sample(execution.runtime, result)
end

function execute_transformer_product(case_id::Symbol)
    execution = transformer_product_network(transformer_product(case_id))
    split_step = TRANSFORMER_EXAMPLE_STEP_COUNT ÷ 2
    samples = Vector{NamedTuple}(undef, TRANSFORMER_EXAMPLE_STEP_COUNT)
    checkpoint = nothing
    split_snapshot_signature = ""
    for step_index in 1:TRANSFORMER_EXAMPLE_STEP_COUNT
        samples[step_index] = advance_transformer_product_step!(execution, step_index)
        if step_index == split_step
            checkpoint = nonlinear_nodal_checkpoint(execution.system)
            split_snapshot_signature =
                TransformerExamples.transformer_apparatus_runtime_snapshot(
                    execution.runtime,
                ).deterministic_signature_sha256
        end
    end
    checkpoint === nothing && error("public transformer split checkpoint was not captured")
    baseline_result = TransformerExamples.transformer_apparatus_result(execution.runtime)
    baseline_tail = samples[(split_step + 1):end]
    restore_nonlinear_nodal_checkpoint!(execution.system, checkpoint)
    replay_tail = [
        advance_transformer_product_step!(execution, step_index)
        for step_index in (split_step + 1):TRANSFORMER_EXAMPLE_STEP_COUNT
    ]
    replay_result = TransformerExamples.transformer_apparatus_result(execution.runtime)
    isequal(replay_tail, baseline_tail) || error(
        "public transformer checkpoint continuation was not bitwise deterministic",
    )
    replay_result.deterministic_signature_sha256 ==
        baseline_result.deterministic_signature_sha256 || error(
            "public transformer final result signature changed after checkpoint replay",
        )
    baseline_result.accepted_step_count == TRANSFORMER_EXAMPLE_STEP_COUNT || error(
        "public transformer product did not accept the declared step count",
    )
    length(baseline_result.event_occurrences) == 1 || error(
        "public transformer product did not apply its one declared topology event",
    )
    return merge(execution, (
        samples=samples,
        result=baseline_result,
        restart_exact=true,
        split_snapshot_signature=split_snapshot_signature,
    ))
end

function transformer_result_quantity_text(quantity)
    if TransformerExamples.transformer_result_quantity_available(quantity)
        return string(TransformerExamples.transformer_result_quantity_value(quantity))
    end
    return "unavailable:$(quantity.reason)"
end

function write_transformer_product(output_dir::AbstractString, execution)
    times = [0.0; getfield.(execution.samples, :time_s)]
    terminal_voltage = [0.0; getfield.(execution.samples, :terminal_voltage_v)]
    terminal_current = [0.0; getfield.(execution.samples, :terminal_current_a)]
    terminal_power = [0.0; getfield.(execution.samples, :terminal_power_w)]
    supplied_energy = [0.0; getfield.(execution.samples, :supplied_energy_j)]
    maximum_kcl = [0.0; getfield.(execution.samples, :maximum_kcl_residual_a)]
    waveform_series = Pair{String,Vector{Float64}}[
        "terminal_1_voltage_v" => terminal_voltage,
        "terminal_1_current_a" => terminal_current,
        "terminal_power_kw" => terminal_power ./ 1.0e3,
    ]
    write_series_csv(
        joinpath(output_dir, "transformer_waveforms.csv"),
        "time_s",
        times,
        [
            waveform_series;
            "supplied_energy_j" => supplied_energy;
            "maximum_network_kcl_residual_a" => maximum_kcl;
        ],
    )
    write_waveform_svg(
        joinpath(output_dir, "transformer_waveforms.svg"),
        times,
        waveform_series;
        title="$(execution.case_id): terminal execution",
        y_label="SI value (power shown in kW)",
    )
    result = execution.result
    open(joinpath(output_dir, "transformer_report.txt"), "w") do io
        println(io, "schema=aimora.public_transformer_product.v1")
        println(io, "case=$(execution.case_id)")
        println(io, "tier=$(TransformerExamples.transformer_apparatus_contract(execution.tier).id)")
        println(io, "description=$(execution.description)")
        println(io, "accepted_steps=$(result.accepted_step_count)")
        println(io, "accepted_time_s=$(result.accepted_time_s)")
        println(io, "event_count=$(length(result.event_occurrences))")
        println(io, "restart_exact=$(execution.restart_exact)")
        println(io, "terminal_count=$(length(result.terminal_order))")
        println(io, "coil_count=$(length(result.coil_order))")
        println(io, "stored_energy_j=$(result.energy.stored_energy_j)")
        println(io, "apparatus_dissipated_energy_j=$(result.energy.apparatus_dissipated_energy_j)")
        println(io, "event_dissipated_energy_j=$(result.energy.total_event_dissipated_energy_j)")
        println(io, "unexplained_balance_residual_j=$(result.energy.unexplained_balance_residual_j)")
        println(io, "maximum_terminal_kcl_residual_a=$(transformer_result_quantity_text(result.residuals.maximum_terminal_kcl_residual_a))")
        println(io, "maximum_internal_kcl_residual_a=$(transformer_result_quantity_text(result.residuals.maximum_internal_kcl_residual_a))")
        println(io, "maximum_magnetic_continuity_residual_wb=$(transformer_result_quantity_text(result.residuals.maximum_magnetic_continuity_residual_wb))")
        println(io, "result_signature_sha256=$(result.deterministic_signature_sha256)")
        println(io, "split_snapshot_signature_sha256=$(execution.split_snapshot_signature)")
        println(io, "uncertainty=$(result.uncertainty)")
        println(io, "validity_domain=$(result.validity_domain)")
        println(io, "unsupported_outputs=$(join(String.(result.unsupported_outputs), ','))")
    end
    write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "$(execution.case_id) public transformer product",
        (
            tier=TransformerExamples.transformer_apparatus_contract(execution.tier).id,
            accepted_steps=result.accepted_step_count,
            event_count=length(result.event_occurrences),
            restart_exact=execution.restart_exact,
            result_signature_sha256=result.deterministic_signature_sha256,
            validity_domain=result.validity_domain,
            limitation=
                "Generic synthetic product only; no ATP/PSCAD equivalence, vendor prediction, protected-standard conformance, insulation design, lifetime, or certification claim.",
        ),
    )
    return execution
end

function run_transformer_product(output_dir::AbstractString, case_id::Symbol)
    execution = execute_transformer_product(case_id)
    write_transformer_product(output_dir, execution)
    return execution
end
