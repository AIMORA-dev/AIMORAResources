#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.EMTStudy
using .ExampleSupport

const TIMESTEP_S = 1.0e-6
const END_TICK = 100
const DC_LINK_VOLTAGE_V = 400.0
const LOAD_RESISTANCE_OHM = 8.0
const LOAD_INDUCTANCE_H = 1.0e-3
const PWM_CARRIER_PERIOD_S = 20.0e-6
const PWM_DUTY = 0.5
const COMMUTATION_DEAD_TIME_S = 2.0e-6

struct ConstantBridgeDuty
    duty::Float64
end

(command::ConstantBridgeDuty)(_bridge, _time_s, _cycle_index) = command.duty

function apply_bridge_pole_command!(bridge, upper_on, time_s, _edge_index)
    return AIMORA.Nonlinear.request_power_semiconductor_bridge_pole!(
        bridge,
        upper_on,
        time_s,
    )
end

function complementary_bridge_leg()
    diode = AIMORA.Nonlinear.AntiparallelDiodeParameters(
        forward_voltage_v = 0.8,
        holding_current_a = 0.0,
        on_conductance_s = 100.0,
    )
    upper = AIMORA.Nonlinear.IGBTSwitch(
        1,
        2;
        gate_driver = AIMORA.Nonlinear.PowerSemiconductorGateDriver(
            initially_on = true,
        ),
        initially_closed = true,
        forward_voltage_drop_v = 1.0,
        on_conductance = 100.0,
        off_conductance = 1.0e-6,
        antiparallel_diode = diode,
        snubber = AIMORA.Nonlinear.SeriesRCSnubber(20.0, 50.0e-9),
    )
    lower = AIMORA.Nonlinear.IGBTSwitch(
        2,
        0;
        gate_driver = AIMORA.Nonlinear.PowerSemiconductorGateDriver(),
        forward_voltage_drop_v = 1.0,
        on_conductance = 100.0,
        off_conductance = 1.0e-6,
        antiparallel_diode = diode,
        snubber = AIMORA.Nonlinear.SeriesRCSnubber(20.0, 50.0e-9),
    )
    return AIMORA.Nonlinear.PowerSemiconductorBridgeLeg(
        upper,
        lower;
        commutation_dead_time_s = COMMUTATION_DEAD_TIME_S,
    )
end

function bridge_commutation_trace()
    bridge = complementary_bridge_leg()
    load = AIMORA.Branches.SeriesRLBranch(
        2,
        0,
        LOAD_RESISTANCE_OHM,
        LOAD_INDUCTANCE_H,
    )
    pwm = EMTExactPWMTask(
        :complementary_bridge_pwm,
        PWM_CARRIER_PERIOD_S,
        ConstantBridgeDuty(PWM_DUTY),
        apply_bridge_pole_command!;
        tick_s = TIMESTEP_S,
        first_time_s = 0.0,
        priority = 0,
    )
    scheduler = EMTExactSampledTaskScheduler(
        TIMESTEP_S;
        tasks = [pwm],
    )
    sample_count = END_TICK + 1
    ticks = collect(0:END_TICK)
    times_s = Float64.(ticks) .* TIMESTEP_S
    midpoint_voltage_v = zeros(sample_count)
    load_current_a = zeros(sample_count)
    upper_gate = zeros(sample_count)
    lower_gate = zeros(sample_count)
    upper_forward = zeros(sample_count)
    lower_forward = zeros(sample_count)
    upper_freewheel = zeros(sample_count)
    lower_freewheel = zeros(sample_count)
    terminal_kcl_residual_a = zeros(sample_count)
    semiconductor_loss_w = zeros(sample_count)
    snubber_loss_w = zeros(sample_count)
    dissipated_energy_j = zeros(sample_count)
    stored_energy_j = zeros(sample_count)
    source_energy_j = zeros(sample_count)
    load_resistor_energy_j = zeros(sample_count)
    load_magnetic_energy_j = zeros(sample_count)
    admittance = zeros(2, 2)
    rhs = zeros(2)
    voltages = [DC_LINK_VOLTAGE_V, 0.0]
    previous_source_power_w = 0.0
    previous_load_loss_w = 0.0

    run_due_emt_sampled_tasks!(scheduler, bridge, 0.0)
    initial_terminal = AIMORA.Nonlinear.power_semiconductor_bridge_terminal_state(
        bridge,
    )
    upper_gate[1] = initial_terminal.upper_switch.gate_applied_on ? 1.0 : 0.0
    lower_gate[1] = initial_terminal.lower_switch.gate_applied_on ? 1.0 : 0.0
    upper_forward[1] = initial_terminal.upper_switch.forward_conducting ? 1.0 : 0.0

    for tick in 1:END_TICK
        sample = tick + 1
        time_s = tick * TIMESTEP_S
        run_due_emt_sampled_tasks!(scheduler, bridge, time_s)
        fill!(admittance, 0.0)
        fill!(rhs, 0.0)
        AIMORA.Branches.stamp!(admittance, rhs, bridge, time_s, TIMESTEP_S)
        AIMORA.Branches.stamp!(admittance, rhs, load, time_s, TIMESTEP_S)
        voltages[2] = (
            rhs[2] - admittance[2, 1] * DC_LINK_VOLTAGE_V
        ) / admittance[2, 2]
        AIMORA.Branches.update!(bridge, voltages, TIMESTEP_S)
        AIMORA.Branches.update!(load, voltages, TIMESTEP_S)
        terminal = AIMORA.Nonlinear.power_semiconductor_bridge_terminal_state(
            bridge,
        )
        midpoint_voltage_v[sample] = voltages[2]
        load_current_a[sample] = load.i_last
        upper_gate[sample] = terminal.upper_switch.gate_applied_on ? 1.0 : 0.0
        lower_gate[sample] = terminal.lower_switch.gate_applied_on ? 1.0 : 0.0
        upper_forward[sample] = terminal.upper_switch.forward_conducting ? 1.0 : 0.0
        lower_forward[sample] = terminal.lower_switch.forward_conducting ? 1.0 : 0.0
        upper_freewheel[sample] =
            terminal.upper_switch.reverse_diode_conducting ? 1.0 : 0.0
        lower_freewheel[sample] =
            terminal.lower_switch.reverse_diode_conducting ? 1.0 : 0.0
        terminal_kcl_residual_a[sample] = terminal.terminal_kcl_residual_a
        semiconductor_loss_w[sample] = terminal.semiconductor_loss_w
        snubber_loss_w[sample] = terminal.snubber_resistor_loss_w
        dissipated_energy_j[sample] = terminal.dissipated_energy_j
        stored_energy_j[sample] = terminal.stored_energy_j
        source_power_w = DC_LINK_VOLTAGE_V * terminal.dc_positive_current_a
        load_loss_w = LOAD_RESISTANCE_OHM * load.i_last^2
        source_energy_j[sample] = source_energy_j[sample - 1] +
            0.5 * TIMESTEP_S * (previous_source_power_w + source_power_w)
        load_resistor_energy_j[sample] = load_resistor_energy_j[sample - 1] +
            0.5 * TIMESTEP_S * (previous_load_loss_w + load_loss_w)
        load_magnetic_energy_j[sample] =
            0.5 * LOAD_INDUCTANCE_H * load.i_last^2
        previous_source_power_w = source_power_w
        previous_load_loss_w = load_loss_w
    end
    return (;
        bridge,
        pwm,
        scheduler,
        ticks,
        times_s,
        midpoint_voltage_v,
        load_current_a,
        upper_gate,
        lower_gate,
        upper_forward,
        lower_forward,
        upper_freewheel,
        lower_freewheel,
        terminal_kcl_residual_a,
        semiconductor_loss_w,
        snubber_loss_w,
        dissipated_energy_j,
        stored_energy_j,
        source_energy_j,
        load_resistor_energy_j,
        load_magnetic_energy_j,
    )
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    trace = bridge_commutation_trace()
    all_off = (trace.upper_gate .+ trace.lower_gate) .== 0.0
    complementary_interlock = all((trace.upper_gate .+ trace.lower_gate) .<= 1.0)
    freewheel_samples = count(>(0.5), trace.lower_freewheel) +
        count(>(0.5), trace.upper_freewheel)
    edge_ticks = getfield.(trace.pwm.occurrences, :tick)
    edge_ticks_unique = length(unique(edge_ticks)) == length(edge_ticks)
    finite_state = all(isfinite, trace.midpoint_voltage_v) &&
        all(isfinite, trace.load_current_a) &&
        all(isfinite, trace.semiconductor_loss_w) &&
        all(isfinite, trace.snubber_loss_w) &&
        all(isfinite, trace.dissipated_energy_j) &&
        all(isfinite, trace.stored_energy_j)
    maximum_kcl_residual_a = maximum(abs, trace.terminal_kcl_residual_a)
    conduction_overlap_count = count(eachindex(trace.times_s)) do sample
        upper_path = trace.upper_forward[sample] + trace.upper_freewheel[sample]
        lower_path = trace.lower_forward[sample] + trace.lower_freewheel[sample]
        upper_path > 0.5 && lower_path > 0.5
    end
    terminal_energy_residual_j = abs(
        trace.source_energy_j[end] -
        trace.load_resistor_energy_j[end] -
        trace.load_magnetic_energy_j[end] -
        trace.dissipated_energy_j[end] -
        trace.stored_energy_j[end],
    )
    relative_terminal_energy_residual = terminal_energy_residual_j /
        max(abs(trace.source_energy_j[end]), eps(Float64))
    complementary_interlock && any(all_off) && freewheel_samples > 0 &&
        conduction_overlap_count == 0 && edge_ticks_unique && finite_state &&
        maximum_kcl_residual_a <= 1.0e-10 &&
        relative_terminal_energy_residual <= 5.0e-4 &&
        minimum(trace.dissipated_energy_j) >= 0.0 &&
        minimum(trace.stored_energy_j) >= 0.0 ||
        error("complementary bridge commutation acceptance checks failed")

    csv_path = write_series_csv(
        joinpath(output_dir, "complementary_bridge_commutation.csv"),
        "time_s",
        trace.times_s,
        [
            "tick" => trace.ticks,
            "midpoint_voltage_v" => trace.midpoint_voltage_v,
            "load_current_a" => trace.load_current_a,
            "upper_gate_applied" => trace.upper_gate,
            "lower_gate_applied" => trace.lower_gate,
            "upper_forward_conducting" => trace.upper_forward,
            "lower_forward_conducting" => trace.lower_forward,
            "upper_freewheel_diode" => trace.upper_freewheel,
            "lower_freewheel_diode" => trace.lower_freewheel,
            "terminal_kcl_residual_a" => trace.terminal_kcl_residual_a,
            "semiconductor_loss_w" => trace.semiconductor_loss_w,
            "snubber_resistor_loss_w" => trace.snubber_loss_w,
            "dissipated_energy_j" => trace.dissipated_energy_j,
            "stored_energy_j" => trace.stored_energy_j,
        ],
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "complementary_bridge_commutation.svg"),
        trace.times_s,
        [
            "midpoint_voltage_pu" => trace.midpoint_voltage_v ./ DC_LINK_VOLTAGE_V,
            "upper_gate" => trace.upper_gate,
            "lower_gate" => trace.lower_gate,
            "upper_freewheel" => trace.upper_freewheel,
            "lower_freewheel" => trace.lower_freewheel,
        ];
        title = "Complementary Bridge Commutation and Freewheel Paths",
        y_label = "gate, diode, and normalized voltage",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Complementary Bridge Commutation",
        (
            timestep_s = TIMESTEP_S,
            dc_link_voltage_v = DC_LINK_VOLTAGE_V,
            load_resistance_ohm = LOAD_RESISTANCE_OHM,
            load_inductance_h = LOAD_INDUCTANCE_H,
            pwm_carrier_period_s = PWM_CARRIER_PERIOD_S,
            pwm_duty = PWM_DUTY,
            commutation_dead_time_s = COMMUTATION_DEAD_TIME_S,
            pwm_edge_count = trace.pwm.edge_count,
            upper_gate_transition_count =
                trace.bridge.upper_switch.gate_driver.transition_count,
            lower_gate_transition_count =
                trace.bridge.lower_switch.gate_driver.transition_count,
            topology_transition_count =
                AIMORA.Nonlinear.power_semiconductor_bridge_topology_transition_count(
                    trace.bridge,
                ),
            all_off_dead_time_sample_count = count(all_off),
            freewheel_sample_count = freewheel_samples,
            complementary_interlock_passed = complementary_interlock,
            simultaneous_conduction_sample_count = conduction_overlap_count,
            pwm_edge_ticks_unique = edge_ticks_unique,
            finite_state_passed = finite_state,
            maximum_terminal_kcl_residual_a = maximum_kcl_residual_a,
            source_energy_j = trace.source_energy_j[end],
            load_resistor_energy_j = trace.load_resistor_energy_j[end],
            load_magnetic_energy_j = trace.load_magnetic_energy_j[end],
            bridge_dissipated_energy_j = trace.dissipated_energy_j[end],
            bridge_stored_energy_j = trace.stored_energy_j[end],
            terminal_energy_residual_j = terminal_energy_residual_j,
            relative_terminal_energy_residual =
                relative_terminal_energy_residual,
            julia_only = true,
        ),
    )
    println("CSV: ", csv_path)
    println("Waveform: ", svg_path)
    println("Summary: ", summary_path)
end

main()
