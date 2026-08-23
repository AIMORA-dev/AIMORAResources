#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA
using LinearAlgebra

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))
using .ExampleSupport

const MachineExamples = AIMORA.ModernMachines
const MACHINE_EXAMPLE_TIMESTEP_S = 10.0e-6
const MACHINE_EXAMPLE_FREQUENCY_HZ = 60.0
const MACHINE_EXAMPLE_STEP_COUNT = 1_000
const MACHINE_EXAMPLE_EVENT_TIME_S = 5.0e-3
const MACHINE_EXAMPLE_SOURCE_PEAK_V = 325.0

function machine_example_identity(case_id::Symbol)
    if case_id === :emt_machine_wound_field_synchronous
        return (
            family=MachineExamples.WoundFieldSynchronousMachine,
            mode=MachineExamples.MachineGeneratorMode,
            rotor_branch_count=0,
            shaft_mass_count=1,
            controls=false,
            description="wound-field synchronous generator with field and d/q damper circuits",
        )
    elseif case_id === :emt_machine_cage_induction
        return (
            family=MachineExamples.CageInductionMachine,
            mode=MachineExamples.MachineMotorMode,
            rotor_branch_count=1,
            shaft_mass_count=1,
            controls=false,
            description="standard single-cage induction motor",
        )
    elseif case_id === :emt_machine_deep_bar_induction
        return (
            family=MachineExamples.CageInductionMachine,
            mode=MachineExamples.MachineMotorMode,
            rotor_branch_count=4,
            shaft_mass_count=1,
            controls=false,
            description="four-branch passive deep-bar induction motor",
        )
    elseif case_id === :emt_machine_permanent_magnet
        return (
            family=MachineExamples.PermanentMagnetSynchronousMachine,
            mode=MachineExamples.MachineGeneratorMode,
            rotor_branch_count=0,
            shaft_mass_count=1,
            controls=false,
            description="salient permanent-magnet synchronous generator",
        )
    elseif case_id === :emt_machine_doubly_fed_induction
        return (
            family=MachineExamples.DoublyFedInductionMachine,
            mode=MachineExamples.MachineGeneratorMode,
            rotor_branch_count=1,
            shaft_mass_count=1,
            controls=false,
            description="doubly fed wound-rotor induction machine with an exposed rotor port",
        )
    elseif case_id === :emt_machine_synchronous_condenser
        return (
            family=MachineExamples.SynchronousCondenserMachine,
            mode=MachineExamples.MachineCondenserMode,
            rotor_branch_count=0,
            shaft_mass_count=1,
            controls=true,
            description="controlled wound-field synchronous condenser",
        )
    elseif case_id === :emt_machine_multimass_controls
        return (
            family=MachineExamples.WoundFieldSynchronousMachine,
            mode=MachineExamples.MachineGeneratorMode,
            rotor_branch_count=0,
            shaft_mass_count=8,
            controls=true,
            description="eight-mass wound-field machine with excitation, governor, and stabilizer tasks",
        )
    end
    throw(ArgumentError("unknown public modern-machine product $(case_id)"))
end

function machine_example_electrical(family)
    wound_field = family in (
        MachineExamples.WoundFieldSynchronousMachine,
        MachineExamples.SynchronousCondenserMachine,
    )
    permanent_magnet = family === MachineExamples.PermanentMagnetSynchronousMachine
    return MachineExamples.MachineElectricalParameters(
        stator_resistance_ohm=0.18,
        zero_sequence_inductance_h=0.012,
        stator_d_leakage_inductance_h=0.006,
        stator_q_leakage_inductance_h=0.007,
        d_axis_magnetizing_inductance_h=0.085,
        q_axis_magnetizing_inductance_h=0.072,
        field_resistance_ohm=wound_field ? 1.2 : 0.0,
        field_leakage_inductance_h=wound_field ? 0.018 : 0.0,
        d_damper_resistance_ohm=wound_field ? 0.45 : 0.0,
        d_damper_leakage_inductance_h=wound_field ? 0.011 : 0.0,
        q_damper_resistance_ohm=wound_field ? 0.52 : 0.0,
        q_damper_leakage_inductance_h=wound_field ? 0.013 : 0.0,
        permanent_magnet_flux_wb=permanent_magnet ? 0.48 : 0.0,
        iron_loss_conductance_s=1.0e-5,
    )
end

function machine_example_rotor_branches(identity)
    return MachineExamples.MachineRotorBranch[
        MachineExamples.MachineRotorBranch(
            Symbol(:rotor_branch_, branch_index);
            resistance_ohm=0.12 + 0.05 * branch_index,
            leakage_inductance_h=0.004 + 0.002 * branch_index,
            terminal_exposed=identity.family in (
                MachineExamples.WoundRotorInductionMachine,
                MachineExamples.DoublyFedInductionMachine,
            ) && branch_index == 1,
        ) for branch_index in 1:identity.rotor_branch_count
    ]
end

function machine_example_shaft(identity)
    synchronous_speed = 2.0 * pi * MACHINE_EXAMPLE_FREQUENCY_HZ / 2.0
    masses = MachineExamples.MachineShaftMass[
        MachineExamples.MachineShaftMass(
            Symbol(:shaft_mass_, mass_index);
            inertia_kg_m2=1.5 + 0.25 * mass_index,
            damping_nm_s_per_rad=0.002 * mass_index,
            initial_speed_rad_s=synchronous_speed,
        ) for mass_index in 1:identity.shaft_mass_count
    ]
    couplings = MachineExamples.MachineShaftCoupling[
        MachineExamples.MachineShaftCoupling(
            Symbol(:shaft_section_, coupling_index),
            masses[coupling_index].id,
            masses[coupling_index + 1].id;
            stiffness_nm_per_rad=2.0e4 + 1.0e3 * coupling_index,
            damping_nm_s_per_rad=2.0 + coupling_index,
        ) for coupling_index in 1:(identity.shaft_mass_count - 1)
    ]
    return masses, couplings, synchronous_speed
end

function machine_example_specification(case_id::Symbol)
    identity = machine_example_identity(case_id)
    masses, couplings, synchronous_speed = machine_example_shaft(identity)
    controls = MachineExamples.MachineControlParameters(
        enabled=identity.controls,
        task_period_s=5.0 * MACHINE_EXAMPLE_TIMESTEP_S,
        voltage_reference_v=230.0,
        excitation_gain=0.02,
        excitation_time_constant_s=0.02,
        field_voltage_min_v=0.0,
        field_voltage_max_v=20.0,
        speed_reference_rad_s=synchronous_speed,
        governor_droop_rad_s_per_nm=0.1,
        governor_time_constant_s=0.04,
        torque_min_nm=-200.0,
        torque_max_nm=200.0,
        stabilizer_gain=0.01,
        stabilizer_washout_s=0.1,
        stabilizer_lead_s=0.02,
        stabilizer_lag_s=0.05,
    )
    field_voltage = identity.family in (
        MachineExamples.WoundFieldSynchronousMachine,
        MachineExamples.SynchronousCondenserMachine,
    ) ? 5.0 : 0.0
    rotor_voltage = identity.family === MachineExamples.DoublyFedInductionMachine ?
        (2.0, -1.0) : (0.0, 0.0)
    provenance = AIMORA.StudyCore.ParameterProvenance(
        "AIMORA generic public modern-machine products",
        "SI",
        "direct synthetic values with one explicit peak-instantaneous phase convention",
        "exact synthetic values; manufacturer, measurement, and model-form uncertainty are unknown",
        "the exact generic public machine product and declared fixed-step execution",
        AIMORA.StudyCore.PhysicalModelParameter,
    )
    specification = MachineExamples.ModernMachineSpecification(
        case_id,
        identity.family;
        operating_mode=identity.mode,
        pole_pairs=2,
        electrical=machine_example_electrical(identity.family),
        rotor_branches=machine_example_rotor_branches(identity),
        saturation=MachineExamples.MachineMagneticCoenergyLaw(
            radial_coefficient_per_wb2_h=0.02,
            cross_coefficient_per_wb2_h=0.01,
            maximum_flux_wb=20.0,
        ),
        shaft_masses=masses,
        shaft_couplings=couplings,
        electromagnetic_mass=first(masses).id,
        controls=controls,
        settings=MachineExamples.MachineRuntimeSettings(
            timestep_s=MACHINE_EXAMPLE_TIMESTEP_S,
            nonlinear_tolerance=1.0e-12,
            maximum_nonlinear_iterations=16,
            energy_tolerance_j=1.0e-6,
        ),
        initialization_mode=MachineExamples.SpecifiedMachineInitialization,
        initial_field_voltage_v=field_voltage,
        initial_rotor_voltage_dq_v=rotor_voltage,
        initial_mechanical_torque_nm=0.0,
        provenance=provenance,
        uncertainty="exact generic inputs; manufacturer, measurement, field, and model-form uncertainty are unknown",
        validity_domain="the exact redistributable $(identity.description) topology, source, parameters, 60 Hz waveform, 10 microsecond timestep, event, and output selection",
    )
    return identity, specification
end

function machine_example_voltage(time_s::Real)
    angle = 2.0 * pi * MACHINE_EXAMPLE_FREQUENCY_HZ * Float64(time_s)
    phase_a_scale = time_s >= MACHINE_EXAMPLE_EVENT_TIME_S ? 0.65 : 1.0
    neutral = time_s >= MACHINE_EXAMPLE_EVENT_TIME_S ? 8.0 : 0.0
    return [
        phase_a_scale * MACHINE_EXAMPLE_SOURCE_PEAK_V * sin(angle),
        MACHINE_EXAMPLE_SOURCE_PEAK_V * sin(angle - 2.0 * pi / 3.0),
        MACHINE_EXAMPLE_SOURCE_PEAK_V * sin(angle + 2.0 * pi / 3.0),
        neutral,
    ]
end

function machine_example_events(identity)
    event_kind = identity.controls ?
        MachineExamples.MachineVoltageReferenceEvent :
        MachineExamples.MachineMechanicalTorqueEvent
    event_value = identity.controls ? 220.0 : 12.0
    return MachineExamples.ModernMachineEvent[
        MachineExamples.ModernMachineEvent(
            :public_operating_command,
            MACHINE_EXAMPLE_EVENT_TIME_S,
            event_kind;
            value=event_value,
        ),
    ]
end

function verify_machine_example_restart(preparation, events)
    split_step = MACHINE_EXAMPLE_STEP_COUNT ÷ 2
    uninterrupted = MachineExamples.modern_machine_runtime(preparation; events=events)
    snapshot = nothing
    for step_index in 1:MACHINE_EXAMPLE_STEP_COUNT
        MachineExamples.advance_modern_machine!(
            uninterrupted,
            machine_example_voltage(step_index * MACHINE_EXAMPLE_TIMESTEP_S);
            time_s=step_index * MACHINE_EXAMPLE_TIMESTEP_S,
        )
        step_index == split_step &&
            (snapshot = MachineExamples.modern_machine_runtime_snapshot(uninterrupted))
    end
    snapshot === nothing && error("public machine split snapshot was not captured")
    restored = MachineExamples.modern_machine_runtime(preparation; events=events)
    MachineExamples.restore_modern_machine_runtime_snapshot!(restored, snapshot)
    for step_index in (split_step + 1):MACHINE_EXAMPLE_STEP_COUNT
        MachineExamples.advance_modern_machine!(
            restored,
            machine_example_voltage(step_index * MACHINE_EXAMPLE_TIMESTEP_S);
            time_s=step_index * MACHINE_EXAMPLE_TIMESTEP_S,
        )
    end
    exact = uninterrupted.accepted_state.flux_wb == restored.accepted_state.flux_wb &&
        uninterrupted.accepted_state.terminal_current_a == restored.accepted_state.terminal_current_a &&
        uninterrupted.shaft_state.angle_rad == restored.shaft_state.angle_rad &&
        uninterrupted.shaft_state.speed_rad_s == restored.shaft_state.speed_rad_s &&
        uninterrupted.control_state.sample_count == restored.control_state.sample_count &&
        uninterrupted.next_event_index == restored.next_event_index
    exact || error("public modern-machine checkpoint continuation was not exact")
    return exact, snapshot.deterministic_signature_sha256
end

function run_machine_product(output_dir::AbstractString, case_id::Symbol)
    identity, specification = machine_example_specification(case_id)
    preparation = MachineExamples.prepare_modern_machine(specification)
    events = machine_example_events(identity)
    trace = MachineExamples.simulate_modern_machine(
        preparation,
        machine_example_voltage;
        duration_s=MACHINE_EXAMPLE_STEP_COUNT * MACHINE_EXAMPLE_TIMESTEP_S,
        events=events,
    )
    restart_exact, snapshot_signature = verify_machine_example_restart(
        preparation,
        events,
    )
    trace.result.diagnostics.accepted_step_count == MACHINE_EXAMPLE_STEP_COUNT ||
        error("public modern-machine product did not accept the declared step count")
    trace.event_count[end] == 1 || error(
        "public modern-machine product did not apply its one declared command event",
    )
    trace.result.diagnostics.maximum_kcl_residual_a <= 1.0e-8 || error(
        "public modern-machine product violates four-wire terminal KCL",
    )
    trace.result.diagnostics.maximum_energy_residual_j <=
        specification.settings.energy_tolerance_j || error(
            "public modern-machine product violates its companion energy tolerance",
        )
    isfinite(trace.result.diagnostics.maximum_energy_quadrature_defect_j) || error(
        "public modern-machine product has a nonfinite endpoint energy quadrature defect",
    )
    mkpath(output_dir)
    MachineExamples.write_modern_machine_trace_csv(
        joinpath(output_dir, "machine_waveforms.csv"),
        trace,
    )
    write_waveform_svg(
        joinpath(output_dir, "machine_waveforms.svg"),
        trace.time_s,
        Pair{String,Vector{Float64}}[
            "phase_a_current_a" => vec(trace.phase_current_a[1, :]),
            "phase_b_current_a" => vec(trace.phase_current_a[2, :]),
            "phase_c_current_a" => vec(trace.phase_current_a[3, :]),
        ];
        title="$(case_id): phase-current response",
        y_label="current (A)",
    )
    write_waveform_svg(
        joinpath(output_dir, "machine_mechanical.svg"),
        trace.time_s,
        Pair{String,Vector{Float64}}[
            "electromagnetic_torque_nm" => trace.electromagnetic_torque_nm,
            "rotor_speed_rad_s" => vec(trace.mechanical_speed_rad_s[1, :]),
            "energy_residual_j" => trace.energy_residual_j,
            "energy_quadrature_defect_j" => trace.energy_quadrature_defect_j,
        ];
        title="$(case_id): torque, speed, and energy residual",
        y_label="declared SI value",
    )
    write(joinpath(output_dir, "machine_report.txt"),
        MachineExamples.modern_machine_report_text(trace) *
        "restart_exact=$(restart_exact)\n" *
        "snapshot_signature_sha256=$(snapshot_signature)\n" *
        "uncertainty=$(specification.uncertainty)\n" *
        "validity_domain=$(specification.validity_domain)\n")
    write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "$(case_id) public modern-machine product",
        (
            family=trace.result.family,
            accepted_steps=trace.result.diagnostics.accepted_step_count,
            event_count=trace.result.diagnostics.event_count,
            shaft_mass_count=identity.shaft_mass_count,
            rotor_branch_count=identity.rotor_branch_count,
            control_samples=trace.result.diagnostics.control_sample_count,
            restart_exact=restart_exact,
            result_signature_sha256=trace.result.deterministic_signature_sha256,
            maximum_kcl_residual_a=trace.result.diagnostics.maximum_kcl_residual_a,
            maximum_energy_residual_j=trace.result.diagnostics.maximum_energy_residual_j,
            maximum_energy_quadrature_defect_j=
                trace.result.diagnostics.maximum_energy_quadrature_defect_j,
            validity_domain=specification.validity_domain,
            limitation="Generic synthetic fixed-step product; no vendor, protected-standard, thermal, protection, field, ATP/PSCAD, HIL, or certification equivalence.",
        ),
    )
    return (; identity, specification, preparation, trace, restart_exact)
end
