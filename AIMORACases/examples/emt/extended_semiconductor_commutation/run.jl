#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.NonlinearNetwork
using .ExampleSupport

const CATALOG_ROOT = abspath(get(ENV, "AIMORA_CATALOGS_PATH",
    joinpath(@__DIR__, "..", "..", "..", "..", "AIMORACatalogs")))
isfile(joinpath(CATALOG_ROOT, "Project.toml")) && pushfirst!(LOAD_PATH, CATALOG_ROOT)
using AIMORACatalogs

const DIODE_CARD = joinpath(dirname(pathof(AIMORACatalogs)), "..", "catalogs", "generic",
    "extended_semiconductor_commutation.toml")
const SAMPLE_COUNT = 80

function generic_energy_table(
    current_axis = [0.0, 20.0],
    voltage_axis = [0.0, 200.0],
    temperature_axis = [250.0, 350.0],
)
    base = Array{Float64}(undef, 2, 2, 2)
    for current_index in 1:2, voltage_index in 1:2, temperature_index in 1:2
        base[current_index, voltage_index, temperature_index] = 1.0e-6 * (
            current_axis[current_index] / 20.0 +
            voltage_axis[voltage_index] / 200.0 +
            (temperature_axis[temperature_index] - 250.0) / 100.0
        )
    end
    return AIMORA.Nonlinear.SwitchingEnergyTable(
        current_axis,
        voltage_axis,
        temperature_axis;
        turn_on_energy_j=base,
        turn_off_energy_j=1.5 .* base,
        reverse_recovery_energy_j=2.0 .* base,
    )
end

function generic_recovered_diode(card::StudyFacet)
    parameters = card.parameters
    provenance = NonlinearParameterProvenance(
        String(parameters[:parameter_source]), "catalogue SI facet",
        String(parameters[:parameter_transformation]), String(parameters[:parameter_uncertainty]),
        String(parameters[:validity]), PhysicalModelParameter,
    )
    fidelity = AIMORA.Nonlinear.PowerSemiconductorExtendedFidelity(;
        recovered_charge=AIMORA.Nonlinear.RecoveredChargeFidelity(
            parameters[:recovered_charge_lifetime_s];
            initial_charge_c=parameters[:initial_recovered_charge_c], provenance,
        ),
        junction_charge=AIMORA.Nonlinear.NonlinearJunctionChargeFidelity(
            parameters[:zero_bias_junction_capacitance_f],
            parameters[:junction_voltage_v],
            parameters[:junction_grading_exponent];
            voltage_domain_v=(Float64(parameters[:terminal_voltage_min_v]),
                Float64(parameters[:terminal_voltage_max_v])), provenance,
        ),
        switching_energy=generic_energy_table(
            parameters[:switching_energy_current_axis_a],
            parameters[:switching_energy_blocking_voltage_axis_v],
            parameters[:switching_energy_temperature_axis_k],
        ),
        thermal=AIMORA.Nonlinear.CauerThermalFidelity(
            parameters[:thermal_capacitance_j_per_k],
            parameters[:thermal_resistance_k_per_w];
            ambient_temperature_k=parameters[:ambient_temperature_k],
            initial_temperature_k=parameters[:initial_temperature_k], provenance,
        ),
        provenance,
    )
    return AIMORA.Nonlinear.DiodeValveSwitch(
        1,
        0;
        on_conductance=parameters[:on_conductance_s],
        off_conductance=parameters[:off_conductance_s],
        extended_fidelity=fidelity,
    )
end

function synthetic_commutation_trace(card::StudyFacet)
    diode = generic_recovered_diode(card)
    timestep_s = Float64(card.parameters[:timestep_s])
    isfinite(timestep_s) && timestep_s > 0.0 || throw(ArgumentError(
        "catalogued commutation timestep must be finite and positive",
    ))
    time_s = collect(1:SAMPLE_COUNT) .* timestep_s
    drive_current_a = [
        sample <= 30 ? 10.0 : sample <= 55 ? -20.0 : -2.0
        for sample in 1:SAMPLE_COUNT
    ]
    linear_system = AIMORA.Nodal.NodalSystem(
        1,
        [
            AIMORA.Branches.ConductanceBranch(1, 0, 0.2),
            AIMORA.Branches.CurrentInjection(
                1,
                time -> drive_current_a[clamp(ceil(Int, time / timestep_s), 1, SAMPLE_COUNT)],
            ),
        ],
    )
    nonlinear_system = AIMORA.NonlinearNodal.NonlinearNodalSystem(
        linear_system,
        [diode];
        scales=AIMORA.NonlinearNetwork.NonlinearNetworkScales(
            [200.0],
            [20.0],
            Float64[],
            Float64[],
        ),
    )
    terminal_voltage_v = zeros(Float64, SAMPLE_COUNT)
    terminal_current_a = zeros(Float64, SAMPLE_COUNT)
    stored_charge_c = zeros(Float64, SAMPLE_COUNT)
    displacement_current_a = zeros(Float64, SAMPLE_COUNT)
    temperature_k = zeros(Float64, SAMPLE_COUNT)
    cumulative_energy_j = zeros(Float64, SAMPLE_COUNT)
    event_lookups = AIMORA.Nonlinear.PowerSemiconductorEventLookup[]
    for sample in 1:SAMPLE_COUNT
        accepted = AIMORA.NonlinearNodal.advance_nonlinear_step_with_event_lookups!(
            nonlinear_system,
            time_s[sample],
            timestep_s,
        )
        result = accepted.result
        append!(event_lookups, accepted.event_lookups)
        result.accepted || error(
            "private nonlinear commutation solve failed at sample $sample: $(result.failure)",
        )
        state = AIMORA.Nonlinear.power_semiconductor_extended_state(diode)
        terminal_voltage_v[sample] = result.voltage_v[1]
        terminal_current_a[sample] = diode.last_current
        stored_charge_c[sample] = state.stored_recovery_charge_c
        displacement_current_a[sample] = state.displacement_current_a
        temperature_k[sample] = state.junction_temperature_k
        cumulative_energy_j[sample] =
            diode.semiconductor_dissipated_energy_j
    end
    return (;
        diode,
        time_s,
        terminal_voltage_v,
        drive_current_a,
        terminal_current_a,
        stored_charge_c,
        displacement_current_a,
        temperature_k,
        cumulative_energy_j,
        event_lookups,
    )
end

function gated_commutation_replay(card::StudyFacet; record_events::Bool=false)
    devices = AIMORA.Nonlinear
    nodal = AIMORA.NonlinearNodal
    dt = 0.1e-6
    gate_off_s, gate_on_s = 25.05e-6, 65.05e-6
    diode = generic_recovered_diode(card)
    thermal = devices.CauerThermalFidelity([0.2, 1.0], [0.5, 2.0];
        initial_temperature_k=[300.0, 300.0])
    diode_thermal = diode.extended_fidelity.thermal
    diode_initial_storage_j = diode_thermal.last_stored_energy_j
    gate_initial_storage_j = thermal.last_stored_energy_j
    tail = devices.TurnOffTailFidelity(4e-6; cutoff_current_a=0.05)
    energy = generic_energy_table()
    igbt = devices.IGBTSwitch(2, 0;
        gate_driver=devices.PowerSemiconductorGateDriver(initially_on=true),
        initially_closed=true, on_conductance=2.0, off_conductance=1e-6,
        extended_fidelity=devices.PowerSemiconductorExtendedFidelity(
            turn_off_tail=tail, switching_energy=energy, thermal=thermal),
    )
    devices.power_semiconductor_event_localization!(igbt)
    devices.request_power_semiconductor_gate!(igbt, false, 0.0;
        earliest_transition_time_s=gate_off_s)
    drive(t) = t <= 30e-6 ? 10.0 : t <= 55e-6 ? -20.0 : -2.0
    circuit = AIMORA.Nodal.NodalSystem(2, [
        AIMORA.Branches.ConductanceBranch(1, 0, 0.2),
        AIMORA.Branches.ConductanceBranch(2, 0, 0.2),
        AIMORA.Branches.ConductanceBranch(1, 2, 0.05),
        AIMORA.Branches.CurrentInjection(1, drive),
        AIMORA.Branches.CurrentInjection(2, _ -> 3.0),
    ])
    network = nodal.NonlinearNodalSystem(circuit, [diode, igbt];
        scales=NonlinearNetworkScales([200.0, 200.0], [20.0, 20.0], Float64[], Float64[]))

    event_lookups = devices.PowerSemiconductorEventLookup[]
    function accepted_row(sample)
        t = sample * dt
        if sample == 640
            devices.request_power_semiconductor_gate!(igbt, true, (sample - 1) * dt;
                earliest_transition_time_s=gate_on_s)
        end
        if record_events
            accepted = nodal.advance_nonlinear_step_with_event_lookups!(network, t, dt)
            result = accepted.result
            append!(event_lookups, accepted.event_lookups)
        else
            result = nodal.advance_nonlinear_step!(network, t, dt)
        end
        result.accepted || error("gated commutation failed at sample $sample: $(result.failure)")
        vd, vg = result.voltage_v
        link = 0.05 * (vd - vg)
        residual = max(abs(0.2 * vd + link + diode.last_current - drive(t)),
                       abs(0.2 * vg - link + igbt.last_current - 3.0))
        residual <= 1e-10 + 1e-7 * max(abs(drive(t)), 3.0) ||
            error("gated commutation KCL failed at sample $sample")
        d = devices.power_semiconductor_extended_state(diode)
        g = devices.power_semiconductor_extended_state(igbt)
        diode_thermal_residual_j = d.thermal_stored_energy_j - diode_initial_storage_j -
            diode_thermal.cumulative_input_energy_j + diode_thermal.cumulative_ambient_energy_j
        gate_thermal_residual_j = g.thermal_stored_energy_j - gate_initial_storage_j -
            thermal.cumulative_input_energy_j + thermal.cumulative_ambient_energy_j
        for (balance_j, cauer) in ((diode_thermal_residual_j, diode_thermal),
                                   (gate_thermal_residual_j, thermal))
            abs(balance_j) <= 1e-12 + 1e-7 *
                max(cauer.cumulative_input_energy_j, cauer.cumulative_ambient_energy_j) ||
                error("gated commutation thermal balance failed at sample $sample")
        end
        return (;
            t, diode_v=vd, gate_v=vg, diode_a=diode.last_current, gate_a=igbt.last_current,
            forward_a=igbt.last_forward_current_a, recovery_c=d.stored_recovery_charge_c,
            junction_c=d.junction_charge_c, displacement_a=d.displacement_current_a,
            tail_a=g.tail_current_a, gate_on=igbt.gate_driver.applied_on,
            gate_edges=igbt.gate_driver.transition_count,
            recovery_edges=d.recovery_zero_event_count, tail_edges=g.tail_cutoff_event_count,
            event=g.last_event_kind, event_j=g.last_event_energy_j,
            on_j=g.cumulative_turn_on_energy_j, off_j=g.cumulative_turn_off_energy_j,
            recovery_j=d.cumulative_reverse_recovery_energy_j,
            diode_heat_j=diode.semiconductor_dissipated_energy_j,
            gate_heat_j=igbt.semiconductor_dissipated_energy_j,
            diode_thermal=Tuple(d.thermal_node_temperature_k),
            gate_thermal=Tuple(g.thermal_node_temperature_k),
            diode_heat_flow_w=d.ambient_heat_flow_w, gate_heat_flow_w=g.ambient_heat_flow_w,
            diode_storage_j=d.thermal_stored_energy_j, gate_storage_j=g.thermal_stored_energy_j,
            diode_thermal_residual_j, gate_thermal_residual_j,
            kcl_residual_a=residual,
        )
    end

    before = map(accepted_row, 1:260)
    anchor = last(before)
    anchor.tail_a > 0 && anchor.recovery_c > 0 && anchor.off_j > 0 ||
        error("restart checkpoint must contain live charge, tail and accepted event energy")
    checkpoint = nodal.nonlinear_nodal_checkpoint(network)
    first_replay_lookup = length(event_lookups) + 1
    uninterrupted = map(accepted_row, 261:800)
    uninterrupted_lookups = copy(event_lookups)
    resize!(event_lookups, first_replay_lookup - 1)
    nodal.restore_nonlinear_nodal_checkpoint!(network, checkpoint)
    restarted = map(accepted_row, 261:800)
    isequal(uninterrupted, restarted) || error("gated commutation restart changed accepted history")
    isequal(event_lookups, uninterrupted_lookups) ||
        error("gated commutation restart changed accepted lookup output")
    rows = vcat(before, uninterrupted)
    final = last(rows)
    rows[250].gate_on && !rows[251].gate_on && !rows[650].gate_on && rows[651].gate_on ||
        error("gated commutation missed the gate-off or gate-on boundary")
    final.gate_edges == 2 && final.recovery_edges == 1 && final.tail_edges == 1 ||
        error("gated commutation did not accept each event once")
    recovery = findfirst(row -> row.recovery_edges == 1, rows)
    cutoff_row = findfirst(row -> row.tail_edges == 1, rows)
    251 < recovery < cutoff_row < 651 ||
        error("gated commutation event order changed")
    for (field, accepted_index) in ((:off_j, 251), (:on_j, 651))
        deposits = findall(>(0), diff(getproperty.(rows, field)))
        deposits == [accepted_index - 1] ||
            error("gated commutation did not deposit $field exactly once")
    end
    recovery_deposits = findall(>(0), diff(getproperty.(rows, :recovery_j)))
    length(recovery_deposits) == 1 && 300 <= only(recovery_deposits) < recovery ||
        error("expected one deposition during reverse recovery, got accepted samples $(recovery_deposits .+ 1)")
    cutoff = gate_off_s + tail.decay_time_s * log(rows[250].forward_a / tail.cutoff_current_a)
    abs(tail.last_cutoff_time_s - cutoff) <= 1e-12 ||
        error("gated commutation tail cutoff disagrees with the exponential limit")
    all(row -> row.recovery_c >= 0 && row.tail_a >= 0 &&
        all(t -> 200 <= t <= 600, row.gate_thermal) &&
        all(t -> 200 <= t <= 600, row.diode_thermal), rows) ||
        error("gated commutation left the passive state domain")
    return rows, anchor, tail.last_cutoff_time_s,
        devices.power_semiconductor_extended_result(igbt), event_lookups
end

# The example is redistributable. Only these public declarations may appear in its report.
function public_semiconductor_provenance(provenance)
    provenance === nothing && return (source="unavailable", uncertainty="unavailable")
    source = provenance.source in (
        "AIMORA-authored synthetic exact case input",
        "AIMORA generic caller-supplied semiconductor parameters",
    ) ? provenance.source : "undisclosed"
    uncertainty = provenance.uncertainty in (
        "unknown",
        "unknown; no manufacturer or measurement inference",
        "unknown unless narrowed by the caller's parameter record",
    ) ? provenance.uncertainty : "undisclosed"
    return (; source, uncertainty)
end

function write_event_lookup_csv(path, traces)
    open(path, "w") do io
        columns = fieldnames(AIMORA.Nonlinear.PowerSemiconductorEventLookup)
        println(io, join((:trace, columns...), ','))
        for (trace, records) in traces, record in records
            values = map(column -> getfield(record, column), columns)
            println(io, join((trace, values...), ','))
        end
    end
    return path
end

function main(args=ARGS)
    AIMORA.require_solver()
    length(args) <= 2 || throw(ArgumentError("usage: run.jl [output_directory [catalog_card]]"))
    asset = AIMORACatalogs.load_asset(length(args) == 2 ? args[2] : DIODE_CARD)
    asset.id === :generic_extended_semiconductor_commutation &&
        asset.equipment_class === :power_semiconductor_switch &&
        asset.manufacturer === nothing ||
        throw(ArgumentError("expected the generic extended semiconductor catalog entry"))
    card = study_facet(asset, :emt)
    card.parameters[:fidelity] == "SwitchingDetailed" &&
        card.parameters[:junction_family] == "generic_diode" ||
        throw(ArgumentError("expected the switching-detailed generic diode catalog facet"))
    trace = synthetic_commutation_trace(card)
    all(isfinite, trace.terminal_current_a) || error("nonfinite terminal current")
    minimum(trace.stored_charge_c) >= 0.0 || error("negative recovered charge")
    maximum(trace.stored_charge_c[31:end]) < trace.stored_charge_c[30] ||
        error("reverse commutation did not deplete recovered charge")
    all(diff(trace.cumulative_energy_j) .>= -eps(Float64)) ||
        error("accepted dissipated energy decreased")
    all(temperature -> 200.0 <= temperature <= 600.0, trace.temperature_k) ||
        error("thermal state left its declared domain")
    output_dir = artifact_directory(args, joinpath(@__DIR__, "output"))
    csv_path = write_series_csv(
        joinpath(output_dir, "extended_semiconductor_commutation.csv"),
        "time_s",
        trace.time_s,
        [
            "terminal_voltage_v" => trace.terminal_voltage_v,
            "drive" => trace.drive_current_a,
            "terminal" => trace.terminal_current_a,
            "stored_recovery_charge_c" => trace.stored_charge_c,
            "displacement_current_a" => trace.displacement_current_a,
            "junction_temperature_k" => trace.temperature_k,
            "cumulative_dissipated_energy_j" => trace.cumulative_energy_j,
        ],
    )
    electrical_waveform_path = write_waveform_svg(
        joinpath(output_dir, "extended_semiconductor_commutation.svg"),
        trace.time_s,
        [
            "drive_current_a" => trace.drive_current_a,
            "terminal_current_a" => trace.terminal_current_a,
        ];
        title="Generic Extended Semiconductor Commutation",
        y_label="current (A)",
    )
    charge_waveform_path = write_waveform_svg(
        joinpath(output_dir, "extended_semiconductor_charge.svg"),
        trace.time_s,
        [
            "recovery_uc" => 1.0e6 .* trace.stored_charge_c,
            "displacement" => trace.displacement_current_a,
        ];
        title="Stored Recovery Charge and Displacement Current",
        y_label="charge (uC) and current (A)",
    )
    thermal_waveform_path = write_waveform_svg(
        joinpath(output_dir, "extended_semiconductor_electrothermal.svg"),
        trace.time_s,
        [
            "temperature_mk" =>
                1.0e3 .* (trace.temperature_k .- first(trace.temperature_k)),
            "energy_mj" => 1.0e3 .* trace.cumulative_energy_j,
        ];
        title="Electrothermal Accepted-State Evolution",
        y_label="temperature rise (mK) and energy (mJ)",
    )
    coupled, anchor, cutoff_s, igbt, coupled_lookups =
        gated_commutation_replay(card; record_events=true)
    lookup_path = write_event_lookup_csv(
        joinpath(output_dir, "semiconductor_event_energy_lookups.csv"),
        ((:diode, trace.event_lookups), (:coupled, coupled_lookups)),
    )
    diode = AIMORA.Nonlinear.power_semiconductor_extended_result(trace.diode)
    diode_model = public_semiconductor_provenance(diode.device_provenance)
    diode_table = public_semiconductor_provenance(diode.component_provenance.switching_energy)
    igbt_model = public_semiconductor_provenance(igbt.device_provenance)
    igbt_table = public_semiconductor_provenance(igbt.component_provenance.switching_energy)
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Generic Extended Semiconductor Commutation",
        (
            timestep_s=first(trace.time_s),
            sample_count=SAMPLE_COUNT,
            initial_recovery_charge_c=first(trace.stored_charge_c),
            final_recovery_charge_c=last(trace.stored_charge_c),
            peak_reverse_current_a=minimum(trace.terminal_current_a),
            final_junction_temperature_k=last(trace.temperature_k),
            final_dissipated_energy_j=last(trace.cumulative_energy_j),
            manufacturer_identity="none",
            extended_result_schema_version=diode.schema_version,
            diode_device_parameter_source=diode_model.source,
            diode_device_parameter_uncertainty=diode_model.uncertainty,
            diode_event_energy_parameter_source=diode_table.source,
            diode_event_energy_parameter_uncertainty=diode_table.uncertainty,
            igbt_device_parameter_source=igbt_model.source,
            igbt_device_parameter_uncertainty=igbt_model.uncertainty,
            igbt_event_energy_parameter_source=igbt_table.source,
            igbt_event_energy_parameter_uncertainty=igbt_table.uncertainty,
            private_solver_required=true,
            unsupported="manufacturer prediction, arbitrary compact models, destructive failure, lifetime, standards, and certification",
        ),
    )
    coupled_path = write_series_csv(
        joinpath(output_dir, "gated_commutation_restart.csv"), "time_s",
        getproperty.(coupled, :t),
        vcat(
            [String(field) => getproperty.(coupled, field) for field in
                (:diode_v, :gate_v, :diode_a, :gate_a, :forward_a, :recovery_c, :junction_c,
                 :displacement_a, :tail_a, :gate_on, :gate_edges, :recovery_edges, :tail_edges,
                 :on_j, :off_j, :recovery_j, :diode_heat_j, :gate_heat_j,
                 :diode_heat_flow_w, :gate_heat_flow_w, :diode_storage_j, :gate_storage_j,
                 :diode_thermal_residual_j, :gate_thermal_residual_j, :kcl_residual_a)],
            ["diode_stage_$(stage)_k" => [row.diode_thermal[stage] for row in coupled] for stage in 1:2],
            ["gate_stage_$(stage)_k" => [row.gate_thermal[stage] for row in coupled] for stage in 1:2],
        ),
    )
    println(lookup_path)
    println(coupled_path)
    println("Restart matched ", length(coupled) - 260, " accepted rows at ", anchor.t,
        " s. Tail cutoff ", cutoff_s, " s. Maximum KCL residual ",
        maximum(getproperty.(coupled, :kcl_residual_a)), " A.")
    println(csv_path)
    println(electrical_waveform_path)
    println(charge_waveform_path)
    println(thermal_waveform_path)
    println(summary_path)
    return nothing
end

main()
