#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA

const SURGE_EXAMPLE_SOLVER_PATH = let
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
    isempty(SURGE_EXAMPLE_SOLVER_PATH) && error(
        "the production solver is required to execute the coupled surge products",
    )
    pushfirst!(LOAD_PATH, SURGE_EXAMPLE_SOLVER_PATH)
    using AIMORASolvers
    AIMORA.activate_solver!(AIMORASolvers.production_backend())
end

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))
using .ExampleSupport

const SurgeExamples = AIMORA.SurgeInsulation
const SurgeNetwork = AIMORA.NonlinearNetwork
const SurgeNodal = AIMORA.NonlinearNodal
const SurgeBranches = AIMORA.Branches
const SurgeStudyCore = AIMORA.StudyCore
const SurgeProtection = AIMORA.ProtectionStudy
const SurgeLineFitting = AIMORA.CoupledLineFitting
const SurgeLineRuntime = AIMORA.CoupledLineRuntime
const SurgeLines = AIMORA.Lines
const SurgeTransformers = AIMORA.TransformerApparatus
const SurgeTACS = AIMORA.TACS

const SURGE_PRODUCT_PROVENANCE = SurgeStudyCore.ParameterProvenance(
    "AIMORA-authored generic public surge and insulation products",
    "SI peak volt ampere siemens ohm henry farad coulomb joule kelvin metre and second",
    "direct deterministic synthetic SI inputs with explicit branch and source orientation",
    "synthetic parameter uncertainty is declared by each product; field and model-form uncertainty remain unknown",
    "five generic public surge and insulation products",
    SurgeStudyCore.PhysicalModelParameter,
)

const SURGE_PRODUCT_TIMING_PROVENANCE = SurgeStudyCore.ParameterProvenance(
    "AIMORA-authored generic public surge and insulation products",
    "integer fixed-step ticks",
    "direct deterministic public event calendar",
    "exact synthetic timing values; field timing uncertainty unknown",
    "three-pole public interruption and restrike product",
    SurgeStudyCore.NumericalPolicyParameter,
)

function public_breaker_specification(timestep_s::Float64)
    return SurgeProtection.EMTBreakerSpecification(
        :generic_three_pole_breaker;
        closed_conductance_s=1.0e3,
        open_conductance_s=1.0e-9,
        opening_travel_ticks=0,
        closing_travel_ticks=0,
        current_zero_required=false,
        current_zero_threshold_a=5.0,
        failure_delay_ticks=200,
        failure_current_threshold_a=5.0,
        reclose_dead_ticks=20,
        reclaim_ticks=20,
        maximum_reclose_shots=1,
        contact_tail_enabled=true,
        physical_provenance=SURGE_PRODUCT_PROVENANCE,
        timing_provenance=SURGE_PRODUCT_TIMING_PROVENANCE,
    )
end

function public_line_runtime_preparation(timestep_s::Float64)
    fit_path = normpath(joinpath(
        @__DIR__,
        "..",
        "line_fitting",
        "overhead",
        "outputs",
        "coupled_line_fit.toml",
    ))
    fit = SurgeLineFitting.read_coupled_line_fit(fit_path)
    return SurgeLineRuntime.prepare_coupled_line_runtime(
        fit,
        SurgeLineRuntime.CoupledLineRuntimeSettings(; timestep_s),
    )
end

function public_transformer_apparatus_preparation(timestep_s::Float64)
    source = SurgeTransformers.TransformerSourceRecord(
        :generic_surge_protected_transformer,
        repeat("5", 64),
        SURGE_PRODUCT_PROVENANCE,
    )
    connection = SurgeTransformers.TransformerConnectionTopology(
        node_order=[:protected_terminal, :secondary_terminal],
        coil_order=[:primary_coil, :secondary_coil],
        winding_order=[:primary_winding, :secondary_winding],
        phase_order=[:phase_a],
        coil_winding=[:primary_winding, :secondary_winding],
        coil_phase=[:phase_a, :phase_a],
        incidence=[1.0 0.0; 0.0 1.0],
        vector_group="Ii0",
        clock_number=0,
        phase_shift_rad=0.0,
    )
    matrices = SurgeTransformers.TransformerTerminalMatrices(
        [0.4 0.02; 0.02 0.5],
        [0.12 0.01; 0.01 0.10];
        capacitance_f=[2.0e-9 0.0; 0.0 1.0e-9],
        conductance_s=[1.0e-7 0.0; 0.0 2.0e-7],
    )
    specification = SurgeTransformers.TransformerApparatusSpecification(
        :generic_surge_protected_transformer,
        SurgeTransformers.LowFrequencyTerminalTier,
        connection,
        SurgeTransformers.LowFrequencyTransformerModel(matrices),
        SurgeTransformers.TransformerRuntimeSettings(
            timestep_s=timestep_s,
            initialization_frequency_hz=60.0,
        );
        phase_count=1,
        rated_power_va=10.0e6,
        rated_voltage_v=33.0e3,
        rated_frequency_hz=60.0,
        sources=[source],
        uncertainty="exact generic public matrices; manufacturer and field uncertainty unknown",
        validity_domain="one generic two-terminal transformer exposed to a public surge impulse",
    )
    return SurgeTransformers.prepare_transformer_apparatus(specification)
end

function public_metal_oxide_characteristic()
    return SurgeExamples.MetalOxideCharacteristic(
        [1.0, 10.0, 100.0, 1.0e3, 10.0e3, 100.0e3],
        [1.0e3, 1.5e3, 2.0e3, 2.5e3, 3.0e3, 4.0e3];
        extrapolation=:power_law,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
end

function public_surge_section(identity::Symbol; impedance_ohm::Float64=400.0, length_m::Float64=30.0)
    return SurgeExamples.SurgePropagationSection(
        identity,
        reshape([impedance_ohm], 1, 1);
        length_m,
        propagation_speed_m_per_s=2.5e8,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
end

function public_product_arc(positive_node::Int=1, negative_node::Int=0)
    return SurgeExamples.CombinedArcBranch(
        positive_node,
        negative_node;
        cassie_power_w=2.0e5,
        mayr_power_w=2.0e3,
        cassie_time_constant_s=20.0e-6,
        mayr_time_constant_s=5.0e-6,
        transition_power_w=2.0e4,
        initial_conductance_s=10.0,
        extinction_current_a=0.1,
        initially_ignited=false,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
end

function public_vacuum_gap(identity::Symbol)
    return SurgeExamples.VacuumInterruptionState(
        identity;
        chopping_current_a=5.0,
        initial_dielectric_strength_v=1.0e3,
        dielectric_recovery_rate_v_per_s=1.0e8,
        maximum_dielectric_strength_v=100.0e3,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
end

function surge_insulation_product_specifications()
    lightning = SurgeExamples.DoubleExponentialLightningImpulse(
        30.0e3,
        2.0e4,
        2.0e6;
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    sequence = SurgeExamples.LightningStrokeSequence(
        :generic_two_stroke_lightning,
        [
            SurgeExamples.LightningStroke(:first_stroke, 0.0, lightning),
            SurgeExamples.LightningStroke(
                :subsequent_stroke,
                100.0e-6,
                SurgeExamples.HeidlerLightningImpulse(
                    12.0e3,
                    0.5e-6,
                    30.0e-6,
                    3.0;
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
            ),
        ],
    )
    tower_sections = [
        public_surge_section(:tower_upper; impedance_ohm=450.0, length_m=20.0),
        public_surge_section(:tower_lower; impedance_ohm=300.0, length_m=25.0),
    ]
    tower = SurgeExamples.TransmissionTowerModel(
        :generic_two_section_tower,
        tower_sections,
        [:tower_top, :crossarm, :footing];
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    characteristic = public_metal_oxide_characteristic()
    terminal_section = public_surge_section(
        :apparatus_terminal_surge_section;
        impedance_ohm=350.0,
        length_m=20.0,
    )
    arrester = SurgeExamples.MetalOxideArrester(
        1,
        0,
        characteristic;
        thermal_capacitance_j_per_k=500.0,
        thermal_resistance_k_per_w=2.0,
        maximum_temperature_k=450.0,
        maximum_energy_j=500.0e3,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    dynamic_equivalent = SurgeExamples.DynamicArresterEquivalent(
        characteristic,
        characteristic;
        series_resistance_ohm=0.05,
        series_inductance_h=0.5e-6,
        filter_resistance_ohm=100.0,
        filter_inductance_h=5.0e-6,
        shunt_capacitance_f=100.0e-12,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    gis = SurgeExamples.GISGILSection(
        :generic_gis_terminal,
        [1.0e-4 0.0; 0.0 1.0e-4],
        [1.0e-6 0.1e-6; 0.1e-6 1.0e-6],
        [1.0e-9 0.0; 0.0 1.0e-9],
        [100.0e-12 -10.0e-12; -10.0e-12 100.0e-12];
        length_m=10.0,
        conductor_names=[:phase, :enclosure],
        enclosure_reference=:ground,
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    interruption_arcs = (
        public_product_arc(1, 2),
        public_product_arc(3, 4),
        public_product_arc(5, 6),
    )
    interruption_gaps = (
        public_vacuum_gap(:pole_a),
        public_vacuum_gap(:pole_b),
        public_vacuum_gap(:pole_c),
    )
    interruption_branches = ntuple(
        index -> SurgeExamples.VacuumInterruptionBranch(
            interruption_arcs[index].positive_node,
            interruption_arcs[index].negative_node,
            interruption_gaps[index],
            interruption_arcs[index];
            closed_conductance_s=1.0e-9,
            open_conductance_s=0.0,
            reignition_conductance_s=10.0,
            provenance=SURGE_PRODUCT_PROVENANCE,
        ),
        3,
    )
    return [
        SurgeExamples.SurgeInsulationProductSpecification(
            :generic_three_pole_interruption_restrike,
            SurgeExamples.InterruptionRestrikeProduct,
            (
                breaker_specification=public_breaker_specification(1.0e-6),
                arc_branches=interruption_arcs,
                vacuum_gaps=interruption_gaps,
                vacuum_branches=interruption_branches,
            );
            timestep_s=1.0e-6,
            stop_time_s=120.0e-6,
            provenance=SURGE_PRODUCT_PROVENANCE,
            uncertainty="generic arc and dielectric parameters; apparatus and field uncertainty unknown",
            validity_domain="three synthetic poles with decaying interruption current and one admitted restrike",
        ),
        SurgeExamples.SurgeInsulationProductSpecification(
            :generic_arrester_protected_terminal,
            SurgeExamples.ArresterProtectedTerminalProduct,
            (
                apparatus_identity=:generic_transformer_terminal,
                apparatus_preparation=public_transformer_apparatus_preparation(0.5e-6),
                arrester,
                dynamic_equivalent,
                terminal_section,
            );
            timestep_s=0.5e-6,
            stop_time_s=200.0e-6,
            provenance=SURGE_PRODUCT_PROVENANCE,
            uncertainty="generic arrester characteristic and terminal parameters; manufacturer uncertainty unknown",
            validity_domain="one synthetic transformer terminal exposed to a 30 kA double-exponential current",
        ),
        SurgeExamples.SurgeInsulationProductSpecification(
            :generic_direct_strike_backflash,
            SurgeExamples.TowerBackflashProduct,
            (
                line_terminal_identity=:generic_overhead_line_terminal,
                line_runtime_preparation=public_line_runtime_preparation(0.5e-6),
                lightning_sequence=sequence,
                tower,
                ground=SurgeExamples.IonizingGroundBranch(
                    7;
                    linear_resistance_ohm=20.0,
                    electrode_radius_m=0.01,
                    maximum_ionized_radius_m=1.0,
                    critical_field_v_per_m=1.0e5,
                    expansion_rate_m_per_v_s=1.0e-8,
                    recovery_rate_per_s=1.0e3,
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
                insulator=SurgeExamples.DisruptiveEffectInsulator(
                    1,
                    0;
                    positive_threshold_voltage_v=250.0e3,
                    negative_threshold_voltage_v=300.0e3,
                    positive_exponent=1.0,
                    negative_exponent=1.0,
                    positive_critical_effect=8.0,
                    negative_critical_effect=10.0,
                    flashover_conductance_s=1.0e3,
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
            );
            timestep_s=0.5e-6,
            stop_time_s=200.0e-6,
            provenance=SURGE_PRODUCT_PROVENANCE,
            uncertainty="generic source tower footing and insulation parameters with explicit model-form uncertainty",
            validity_domain="one two-section tower connected to one line surge termination and ionizing footing",
        ),
        SurgeExamples.SurgeInsulationProductSpecification(
            :generic_gis_corona_terminal,
            SurgeExamples.GISCoronaTerminalProduct,
            (
                terminal_identity=:generic_gis_terminal,
                gis_section=gis,
                corona=SurgeExamples.DynamicCoronaBranch(
                    1,
                    0;
                    base_capacitance_f=1.0e-9,
                    incremental_capacitance_f_per_v=1.0e-15,
                    onset_voltage_v=100.0e3,
                    extinction_voltage_v=80.0e3,
                    loss_conductance_s=1.0e-7,
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
                insulator=SurgeExamples.LeaderProgressionInsulator(
                    1,
                    0;
                    gap_length_m=0.2,
                    positive_inception_field_v_per_m=1.0e6,
                    negative_inception_field_v_per_m=1.2e6,
                    positive_velocity_coefficient=1.0e-3,
                    negative_velocity_coefficient=0.8e-3,
                    velocity_exponent=1.0,
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
            );
            timestep_s=0.02e-6,
            stop_time_s=10.0e-6,
            provenance=SURGE_PRODUCT_PROVENANCE,
            uncertainty="generic GIS matrix corona and spacer parameters; geometry and field uncertainty unknown",
            validity_domain="one synthetic two-conductor GIS/GIL terminal section below 1 MHz output interpretation",
        ),
        SurgeExamples.SurgeInsulationProductSpecification(
            :generic_seeded_insulation_ensemble,
            SurgeExamples.StatisticalInsulationProduct,
            (
                study_plan=SurgeExamples.InsulationStudyPlan(
                    :generic_seeded_insulation_ensemble;
                    sample_count=2048,
                    seed=20260824,
                    stress_mean_v=800.0e3,
                    stress_standard_deviation_v=80.0e3,
                    strength_mean_v=1.0e6,
                    strength_standard_deviation_v=100.0e3,
                    stress_strength_correlation=0.2,
                    provenance=SURGE_PRODUCT_PROVENANCE,
                ),
            );
            timestep_s=1.0,
            stop_time_s=1.0,
            provenance=SURGE_PRODUCT_PROVENANCE,
            uncertainty="explicit synthetic correlated Gaussian stress and strength distributions",
            validity_domain="one preregistered deterministic 2048-sample synthetic ensemble",
        ),
    ]
end

function surge_nonlinear_system(
    node_count::Int,
    linear_elements,
    devices;
    voltage_scale_v,
    current_scale_a,
)
    return SurgeNodal.NonlinearNodalSystem(
        AIMORA.Nodal.NodalSystem(node_count, linear_elements),
        devices;
        scales=SurgeNetwork.NonlinearNetworkScales(
            Float64.(voltage_scale_v),
            Float64.(current_scale_a),
            Float64[],
            Float64[],
        ),
    )
end

function run_interruption_product(preparation, output_directory)
    specification = preparation.specification
    components = preparation.components
    timestep = specification.timestep_s
    times = collect(timestep:timestep:specification.stop_time_s)
    phase_scales = (1.0, 1.0, 1.0)
    currents = [zeros(length(times)) for _ in 1:3]
    voltages = [zeros(length(times)) for _ in 1:3]
    states = [zeros(length(times)) for _ in 1:3]
    breaker = SurgeProtection.EMTBreakerRuntime(
        components.breaker_specification;
        tick_s=timestep,
    )
    terminals = ((1, 2), (3, 4), (5, 6))
    binding = AIMORA.materialize_emt_breaker_poles(
        breaker,
        components.breaker_specification,
        terminals,
    )
    linear_elements = Any[]
    for (pole, (source_node, load_node)) in enumerate(terminals)
        source_voltage(time_s) = begin
            interruption = 48.0e3 * phase_scales[pole] *
                max(1.0 - time_s / 80.0e-6, 0.0)
            recovery = time_s <= 90.0e-6 ? 0.0 :
                80.0e3 * phase_scales[pole] *
                (1.0 - exp(-(time_s - 90.0e-6) / 5.0e-6))
            interruption + recovery
        end
        push!(linear_elements, SurgeBranches.TwoTerminalTheveninSource(
            source_node,
            0,
            0.1,
            source_voltage,
        ))
        push!(linear_elements, binding.network_elements[pole])
        push!(linear_elements, SurgeBranches.ConductanceBranch(load_node, 0, 0.02))
    end
    devices = Any[
        components.arc_branches...,
        components.vacuum_branches...,
    ]
    system = surge_nonlinear_system(
        6,
        linear_elements,
        devices;
        voltage_scale_v=fill(80.0e3, 6),
        current_scale_a=fill(1.0e3, 6),
    )
    separation_time = 20.0e-6
    separation_tick = round(Int, separation_time / timestep)
    previous_voltage = (0.0, 0.0, 0.0)
    previous_current = (0.0, 0.0, 0.0)
    localized_event_count = 0
    for (index, time_s) in pairs(times)
        if index == separation_tick
            SurgeProtection.request_breaker_trip!(
                breaker,
                components.breaker_specification,
                index,
            )
            for (arc, gap) in zip(components.arc_branches, components.vacuum_gaps)
                SurgeExamples.request_vacuum_open!(gap, separation_time)
                SurgeExamples.ignite_arc!(arc, 10.0; time_s=separation_time)
            end
        end
        SurgeProtection.advance_emt_breaker!(
            breaker,
            components.breaker_specification,
            index,
            previous_voltage,
            previous_current,
        )
        SurgeProtection.synchronize_emt_breaker_poles!(
            binding,
            breaker,
            components.breaker_specification,
        )
        result = SurgeNodal.advance_nonlinear_step!(
            system,
            time_s,
            timestep;
            discontinuity_treatment=index == separation_tick ?
                :two_backward_euler_half_steps : :none,
            discontinuity_reason=index == separation_tick ? :topology_change : :none,
        )
        result.accepted || error("interruption product failed at $time_s: $(result.failure)")
        result.diagnostics.discontinuity_reason === :localized_event &&
            (localized_event_count += 1)
        pole_voltage = ntuple(pole -> begin
            source_node, load_node = terminals[pole]
            result.voltage_v[source_node] - result.voltage_v[load_node]
        end, 3)
        pole_current = ntuple(pole -> components.arc_branches[pole].accepted_current_a, 3)
        previous_voltage = pole_voltage
        previous_current = pole_current
        for pole in 1:3
            gap = components.vacuum_gaps[pole]
            currents[pole][index] = pole_current[pole]
            voltages[pole][index] = pole_voltage[pole]
            states[pole][index] = gap.state === :closed ? 0.0 :
                gap.state === :separating ? 1.0 : gap.state === :open ? 2.0 : 3.0
        end
    end
    series = Pair[
        "pole_a_current_a" => currents[1],
        "pole_b_current_a" => currents[2],
        "pole_c_current_a" => currents[3],
        "pole_a_gap_state" => states[1],
        "pole_b_gap_state" => states[2],
        "pole_c_gap_state" => states[3],
    ]
    csv = write_series_csv(joinpath(output_directory, "interruption_restrike.csv"), "time_s", times, series)
    svg = write_waveform_svg(
        joinpath(output_directory, "interruption_restrike.svg"),
        times,
        Pair["pole_a_current_a" => currents[1], "pole_b_current_a" => currents[2], "pole_c_current_a" => currents[3]];
        title="Three-pole arc interruption and vacuum-gap state",
        y_label="current (A)",
    )
    return (
        csv=csv,
        svg=svg,
        peak_voltage_v=maximum(maximum(abs, values) for values in voltages),
        localized_event_count,
        breaker_event_count=length(breaker.events),
        chop_count=sum(gap.chop_count for gap in components.vacuum_gaps),
        restrike_count=sum(gap.restrike_count for gap in components.vacuum_gaps),
    )
end

function run_arrester_product(preparation, output_directory)
    specification = preparation.specification
    arrester = preparation.components.arrester
    impulse = SurgeExamples.DoubleExponentialLightningImpulse(
        30.0e3,
        2.0e4,
        2.0e6;
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    source(time_s) = SurgeExamples.lightning_current_a(impulse, time_s)
    apparatus_runtime = SurgeTransformers.transformer_apparatus_runtime(
        preparation.components.apparatus_preparation,
        [1, 2],
    )
    system = surge_nonlinear_system(
        2,
        [
            SurgeBranches.ConductanceBranch(1, 0, 1.0e-6),
            SurgeBranches.ConductanceBranch(2, 0, 0.02),
            SurgeBranches.CurrentInjection(1, source),
        ],
        [arrester, apparatus_runtime];
        voltage_scale_v=[4.0e3, 4.0e3],
        current_scale_a=[30.0e3, 30.0e3],
    )
    timestep = specification.timestep_s
    times = collect(timestep:timestep:specification.stop_time_s)
    source_current = zeros(length(times))
    terminal_voltage = similar(source_current)
    arrester_current = similar(source_current)
    absorbed_energy = similar(source_current)
    for (index, time_s) in pairs(times)
        result = SurgeNodal.advance_nonlinear_step!(system, time_s, timestep)
        result.accepted || error("arrester terminal failed at $time_s: $(result.failure)")
        source_current[index] = source(time_s)
        terminal_voltage[index] = result.voltage_v[1]
        arrester_current[index] = source_current[index] - 1.0e-6 * terminal_voltage[index]
        absorbed_energy[index] = SurgeExamples.arrester_absorbed_energy_j(arrester)
    end
    series = Pair[
        "source_current_a" => source_current,
        "terminal_voltage_v" => terminal_voltage,
        "arrester_current_a" => arrester_current,
        "absorbed_energy_j" => absorbed_energy,
    ]
    csv = write_series_csv(joinpath(output_directory, "arrester_terminal.csv"), "time_s", times, series)
    svg = write_waveform_svg(
        joinpath(output_directory, "arrester_terminal.svg"),
        times,
        Pair["terminal_voltage_v" => terminal_voltage, "arrester_current_a" => arrester_current];
        title="Arrester-protected apparatus terminal",
        y_label="SI terminal quantities",
    )
    apparatus_result = SurgeTransformers.transformer_apparatus_result(apparatus_runtime)
    return (
        csv=csv,
        svg=svg,
        peak_residual_voltage_v=maximum(abs, terminal_voltage),
        absorbed_energy_j=last(absorbed_energy),
        apparatus_signature=apparatus_result.deterministic_signature_sha256,
        apparatus_step_count=apparatus_result.accepted_step_count,
    )
end

function run_tower_product(preparation, output_directory)
    specification = preparation.specification
    components = preparation.components
    source(time_s) = SurgeExamples.lightning_sequence_current_a(components.lightning_sequence, time_s)
    line = SurgeLines.coupled_frequency_dependent_line(
        components.line_runtime_preparation,
        [1, 2, 3],
        [4, 5, 6],
    )
    flashover_control = Ref(-1.0)
    flashover_shunt = SurgeTACS.TACSControlledSwitch(
        4,
        7,
        flashover_control;
        on_conductance=1.0e3,
        off_conductance=0.0,
        initially_closed=false,
    )
    line_system = surge_nonlinear_system(
        7,
        Any[
            line,
            (SurgeBranches.ConductanceBranch(node, 0, 1.0 / 400.0) for node in 1:6)...,
            SurgeBranches.CurrentInjection(4, source),
            flashover_shunt,
        ],
        [components.ground];
        voltage_scale_v=[fill(1.0e6, 6)..., 300.0e3],
        current_scale_a=fill(30.0e3, 7),
    )
    stress_voltage_v = Ref(0.0)
    insulation_system = surge_nonlinear_system(
        1,
        [SurgeBranches.TheveninSource(1, 1.0, _time_s -> stress_voltage_v[])],
        [components.insulator];
        voltage_scale_v=[1.0e6],
        current_scale_a=[1.0e6],
    )
    timestep = specification.timestep_s
    times = collect(timestep:timestep:specification.stop_time_s)
    source_current = zeros(length(times))
    tower_top_voltage = similar(source_current)
    ground_rise = similar(source_current)
    insulator_stress = similar(source_current)
    flashover_state = similar(source_current)
    for (index, time_s) in pairs(times)
        line_result = SurgeNodal.advance_nonlinear_step!(line_system, time_s, timestep)
        line_result.accepted || error(
            "tower/backflash line partition failed at $time_s: $(line_result.failure)",
        )
        source_current[index] = source(time_s)
        tower_top_voltage[index] = line_result.voltage_v[4]
        ground_rise[index] = line_result.voltage_v[7]
        stress_voltage_v[] = line_result.voltage_v[4] - line_result.voltage_v[7]
        insulation_result = SurgeNodal.advance_nonlinear_step!(
            insulation_system,
            time_s,
            timestep,
        )
        insulation_result.accepted || error(
            "tower/backflash insulation partition failed at $time_s: $(insulation_result.failure)",
        )
        insulator_stress[index] = only(insulation_result.voltage_v)
        components.insulator.flashed && (flashover_control[] = 1.0)
        flashover_state[index] = components.insulator.flashed ? 1.0 : 0.0
    end
    series = Pair[
        "lightning_current_a" => source_current,
        "tower_top_voltage_v" => tower_top_voltage,
        "ground_potential_rise_v" => ground_rise,
        "insulator_stress_v" => insulator_stress,
        "flashover_state" => flashover_state,
    ]
    csv = write_series_csv(joinpath(output_directory, "tower_backflash.csv"), "time_s", times, series)
    svg = write_waveform_svg(
        joinpath(output_directory, "tower_backflash.svg"),
        times,
        Pair["tower_top_voltage_v" => tower_top_voltage, "ground_rise_v" => ground_rise, "insulator_stress_v" => insulator_stress];
        title="Direct-strike tower, ionizing footing, and backflash stress",
        y_label="voltage (V)",
    )
    return (
        csv=csv,
        svg=svg,
        flashover=components.insulator.flashed,
        tower_travel_time_s=SurgeExamples.tower_total_travel_time_s(components.tower),
        maximum_ground_rise_v=maximum(abs, ground_rise),
        line_runtime_signature=components.line_runtime_preparation.deterministic_signature_sha256,
        line_step_count=line.runtime_state.accepted_step_count,
        line_minimum_supplied_energy_j=line.runtime_state.minimum_cumulative_supplied_energy_j,
    )
end

function run_gis_product(preparation, output_directory)
    specification = preparation.specification
    components = preparation.components
    impulse = SurgeExamples.HeidlerLightningImpulse(
        2.0e3,
        0.1e-6,
        3.0e-6,
        3.0;
        provenance=SURGE_PRODUCT_PROVENANCE,
    )
    source(time_s) = SurgeExamples.lightning_current_a(impulse, time_s)
    system = surge_nonlinear_system(
        1,
        [
            SurgeBranches.ConductanceBranch(1, 0, 1.0 / 60.0),
            SurgeBranches.CurrentInjection(1, source),
        ],
        [components.corona, components.insulator];
        voltage_scale_v=[120.0e3],
        current_scale_a=[2.0e3],
    )
    timestep = specification.timestep_s
    times = collect(timestep:timestep:specification.stop_time_s)
    terminal_voltage = zeros(length(times))
    corona_charge = similar(terminal_voltage)
    corona_loss = similar(terminal_voltage)
    leader_length = similar(terminal_voltage)
    for (index, time_s) in pairs(times)
        result = SurgeNodal.advance_nonlinear_step!(system, time_s, timestep)
        result.accepted || error("GIS/corona product failed at $time_s: $(result.failure)")
        terminal_voltage[index] = only(result.voltage_v)
        corona_charge[index] = SurgeExamples.corona_charge_c(components.corona)
        corona_loss[index] = SurgeExamples.corona_dissipated_energy_j(components.corona)
        leader_length[index] = SurgeExamples.leader_progression_state(components.insulator).length_m
    end
    series = Pair[
        "terminal_voltage_v" => terminal_voltage,
        "corona_charge_c" => corona_charge,
        "corona_loss_j" => corona_loss,
        "leader_length_m" => leader_length,
    ]
    csv = write_series_csv(joinpath(output_directory, "gis_corona.csv"), "time_s", times, series)
    svg = write_waveform_svg(
        joinpath(output_directory, "gis_corona.svg"),
        times,
        Pair["terminal_voltage_v" => terminal_voltage, "corona_charge_c" => corona_charge];
        title="GIS/GIL terminal and dynamic corona response",
        y_label="SI terminal quantities",
    )
    series_impedance = SurgeExamples.gis_gil_series_impedance_ohm(components.gis_section, 1.0e6)
    shunt_admittance = SurgeExamples.gis_gil_shunt_admittance_s(components.gis_section, 1.0e6)
    return (
        csv=csv,
        svg=svg,
        peak_terminal_voltage_v=maximum(abs, terminal_voltage),
        series_matrix_norm_ohm=maximum(abs, series_impedance),
        shunt_matrix_norm_s=maximum(abs, shunt_admittance),
    )
end

function run_statistical_product(preparation, output_directory)
    summary = SurgeExamples.run_insulation_study(preparation.components.study_plan)
    indices = collect(1:summary.sample_count)
    margins = getfield.(summary.samples, :margin_v)
    failures = Float64.(getfield.(summary.samples, :failed))
    csv = write_series_csv(
        joinpath(output_directory, "insulation_statistics.csv"),
        "sample_index",
        indices,
        Pair["margin_v" => margins, "failed" => failures],
    )
    svg = write_waveform_svg(
        joinpath(output_directory, "insulation_statistics.svg"),
        indices,
        Pair["margin_v" => margins];
        title="Seeded insulation stress-strength margins",
        x_label="sample index",
        y_label="margin (V)",
    )
    return (
        csv=csv,
        svg=svg,
        failure_probability=summary.empirical_failure_probability,
        confidence_lower=summary.confidence_lower,
        confidence_upper=summary.confidence_upper,
        signature=summary.signature,
    )
end

function run_public_surge_insulation_products(output_directory::AbstractString)
    mkpath(output_directory)
    specifications = surge_insulation_product_specifications()
    preparations = [SurgeExamples.prepare_surge_insulation_product(specification) for specification in specifications]
    readiness = [
        SurgeExamples.surge_insulation_product_readiness(
            preparation;
            production_backend_available=AIMORA.solver_available(),
        ) for preparation in preparations
    ]
    all(item -> item.ready && item.production_backend_available, readiness) ||
        error("surge product preparation is not ready for coupled execution")
    results = [
        run_interruption_product(preparations[1], output_directory),
        run_arrester_product(preparations[2], output_directory),
        run_tower_product(preparations[3], output_directory),
        run_gis_product(preparations[4], output_directory),
        run_statistical_product(preparations[5], output_directory),
    ]
    summary = write_key_value_summary(
        joinpath(output_directory, "summary.md"),
        "Generic Surge and Insulation Products",
        (
            product_count=length(specifications),
            interruption_peak_voltage_v=results[1].peak_voltage_v,
            interruption_localized_event_count=results[1].localized_event_count,
            interruption_breaker_event_count=results[1].breaker_event_count,
            interruption_chop_count=results[1].chop_count,
            interruption_restrike_count=results[1].restrike_count,
            arrester_peak_residual_voltage_v=results[2].peak_residual_voltage_v,
            arrester_absorbed_energy_j=results[2].absorbed_energy_j,
            transformer_apparatus_step_count=results[2].apparatus_step_count,
            transformer_apparatus_signature=results[2].apparatus_signature,
            tower_flashover=results[3].flashover,
            tower_travel_time_s=results[3].tower_travel_time_s,
            maximum_ground_rise_v=results[3].maximum_ground_rise_v,
            coupled_line_step_count=results[3].line_step_count,
            coupled_line_runtime_signature=results[3].line_runtime_signature,
            coupled_line_minimum_supplied_energy_j=results[3].line_minimum_supplied_energy_j,
            gis_peak_terminal_voltage_v=results[4].peak_terminal_voltage_v,
            statistical_failure_probability=results[5].failure_probability,
            statistical_confidence_lower=results[5].confidence_lower,
            statistical_confidence_upper=results[5].confidence_upper,
            deterministic_signatures=join(getfield.(readiness, :deterministic_signature_sha256), ","),
            scientific_limit="generic nonvendor nonstandard noncertifying public demonstration; no insulation design or ATP/PSCAD equivalence claim",
        ),
    )
    return (specifications=specifications, preparations=preparations, readiness=readiness, results=results, summary=summary)
end
