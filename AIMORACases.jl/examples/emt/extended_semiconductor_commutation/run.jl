#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.NonlinearNetwork
using .ExampleSupport

const TIMESTEP_S = 1.0e-6
const SAMPLE_COUNT = 80

function generic_energy_table()
    current_axis = [0.0, 20.0]
    voltage_axis = [0.0, 200.0]
    temperature_axis = [250.0, 350.0]
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

function generic_recovered_diode()
    fidelity = AIMORA.Nonlinear.PowerSemiconductorExtendedFidelity(
        recovered_charge=AIMORA.Nonlinear.RecoveredChargeFidelity(
            5.0e-6;
            initial_charge_c=20.0e-6,
        ),
        junction_charge=AIMORA.Nonlinear.NonlinearJunctionChargeFidelity(
            200.0e-9,
            50.0,
            0.45;
            voltage_domain_v=(-200.0, 200.0),
        ),
        switching_energy=generic_energy_table(),
        thermal=AIMORA.Nonlinear.CauerThermalFidelity(
            [0.2, 1.0],
            [0.5, 2.0];
            initial_temperature_k=[300.0, 300.0],
        ),
    )
    return AIMORA.Nonlinear.DiodeValveSwitch(
        1,
        0;
        on_conductance=2.0,
        off_conductance=1.0e-6,
        extended_fidelity=fidelity,
    )
end

function synthetic_commutation_trace()
    diode = generic_recovered_diode()
    time_s = collect(1:SAMPLE_COUNT) .* TIMESTEP_S
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
                time -> drive_current_a[clamp(ceil(Int, time / TIMESTEP_S), 1, SAMPLE_COUNT)],
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
    for sample in 1:SAMPLE_COUNT
        result = AIMORA.NonlinearNodal.advance_nonlinear_step!(
            nonlinear_system,
            time_s[sample],
            TIMESTEP_S,
        )
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
    )
end

function main(args=ARGS)
    AIMORA.require_solver()
    trace = synthetic_commutation_trace()
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
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Generic Extended Semiconductor Commutation",
        (
            timestep_s=TIMESTEP_S,
            sample_count=SAMPLE_COUNT,
            initial_recovery_charge_c=first(trace.stored_charge_c),
            final_recovery_charge_c=last(trace.stored_charge_c),
            peak_reverse_current_a=minimum(trace.terminal_current_a),
            final_junction_temperature_k=last(trace.temperature_k),
            final_dissipated_energy_j=last(trace.cumulative_energy_j),
            manufacturer_identity="none",
            private_solver_required=true,
            unsupported="manufacturer prediction, arbitrary compact models, destructive failure, lifetime, standards, and certification",
        ),
    )
    println(csv_path)
    println(electrical_waveform_path)
    println(charge_waveform_path)
    println(thermal_waveform_path)
    println(summary_path)
    return nothing
end

main()
