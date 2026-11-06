using Test
using AIMORAReferenceModels

@testset "independent FACTS shunt-compensator equations" begin
    omega = 2pi * 50.0
    inductance = 50.0e-3
    capacitance = 100.0e-6
    @test independent_tcr_fundamental_susceptance(omega, inductance, pi / 2) ≈
        -inv(omega * inductance)
    @test independent_tcr_fundamental_susceptance(omega, inductance, pi) ≈ 0.0 atol=1.0e-15
    @test independent_tsc_fundamental_susceptance(omega, capacitance) ≈
        omega * capacitance
    @test independent_svc_fundamental_susceptance(
        omega,
        inductance,
        2pi / 3,
        capacitance,
    ) ≈ independent_tcr_fundamental_susceptance(omega, inductance, 2pi / 3) +
        independent_tsc_fundamental_susceptance(omega, capacitance)
    @test_throws ArgumentError independent_tcr_fundamental_susceptance(
        omega,
        inductance,
        pi / 3,
    )
end

function independent_generic_shunt_compensator(family)
    return independent_switching_shunt_compensator_trace(
        family=family,
        source_phase_peak_voltage_v=400.0 * sqrt(2.0 / 3.0),
        source_frequency_hz=50.0,
        source_resistance_ohm=0.5,
        tcr_resistance_ohm=1.0,
        tcr_inductance_h=50.0e-3,
        tcr_firing_angle_rad=2pi / 3,
        tsc_resistance_ohm=1.0,
        tsc_damping_inductance_h=1.0e-3,
        tsc_capacitance_f=100.0e-6,
        tsc_connection_angle_rad=pi / 2,
        valve_forward_voltage_v=1.0,
        minimum_pulse_s=20.0e-6,
        stop_time_s=15.0e-3,
        fixed_step_s=10.0e-6,
    )
end

@testset "independent switching-detailed shunt-compensator recurrence" begin
    for family in (:tcr, :tsc, :svc)
        trace = independent_generic_shunt_compensator(family)
        @test length(trace.time_s) == 1_501
        @test all(isfinite, trace.bus_voltage_v)
        @test all(>=(0.0), trace.stored_energy_j)
        @test any(trace.conducting_state)
        @test any(event -> event.kind === :forward_turn_on, trace.events)
        @test any(event -> event.kind === :forward_extinction, trace.events)
        family in (:tcr, :svc) && @test maximum(abs, trace.tcr_current_a) > 0.0
        family in (:tsc, :svc) && @test maximum(abs, trace.tsc_current_a) > 0.0
        repeated = independent_generic_shunt_compensator(family)
        @test repeated.tcr_current_a == trace.tcr_current_a
        @test repeated.tsc_current_a == trace.tsc_current_a
        @test repeated.conducting_state == trace.conducting_state
        @test repeated.events == trace.events
    end
end

function independent_generic_series_compensator(; fixed_step_s=10.0e-6)
    return independent_switching_series_compensator_trace(
        source_phase_peak_voltage_v=400.0 * sqrt(2.0 / 3.0),
        source_frequency_hz=50.0,
        source_resistance_ohm=0.5,
        load_resistance_ohm=10.0,
        load_inductance_h=20.0e-3,
        capacitance_f=200.0e-6,
        reactor_resistance_ohm=0.2,
        reactor_inductance_h=2.0e-3,
        firing_angle_rad=2pi / 3,
        valve_forward_voltage_v=1.0,
        minimum_pulse_s=20.0e-6,
        # Exercise natural turn-off: the first current extinction follows 5 ms.
        stop_time_s=20.0e-3,
        fixed_step_s=fixed_step_s,
    )
end

@testset "independent switching-detailed series-compensator recurrence" begin
    trace = independent_generic_series_compensator()
    @test length(trace.time_s) == 2_001
    @test all(isfinite, trace.sending_voltage_v)
    @test all(isfinite, trace.receiving_voltage_v)
    @test all(>=(0.0), trace.stored_energy_j)
    @test maximum(abs, trace.line_current_a) > 0.0
    @test maximum(abs, trace.capacitor_voltage_v) > 0.0
    @test maximum(abs, trace.reactor_current_a) > 0.0
    @test any(trace.conducting_state)
    @test any(event -> event.kind === :forward_turn_on, trace.events)
    @test any(event -> event.kind === :forward_extinction, trace.events)
    repeated = independent_generic_series_compensator()
    @test repeated.line_current_a == trace.line_current_a
    @test repeated.capacitor_voltage_v == trace.capacitor_voltage_v
    @test repeated.reactor_current_a == trace.reactor_current_a
    @test repeated.conducting_state == trace.conducting_state
    @test repeated.events == trace.events
    refined = independent_generic_series_compensator(fixed_step_s=5.0e-6)
    @test maximum(abs, refined.line_current_a[:, end]) > 0.0
    @test_throws ArgumentError independent_switching_series_compensator_trace(
        source_phase_peak_voltage_v=400.0,
        source_frequency_hz=50.0,
        source_resistance_ohm=0.5,
        load_resistance_ohm=10.0,
        load_inductance_h=20.0e-3,
        capacitance_f=200.0e-6,
        reactor_resistance_ohm=0.2,
        reactor_inductance_h=2.0e-3,
        firing_angle_rad=pi / 3,
        minimum_pulse_s=20.0e-6,
        stop_time_s=5.0e-3,
        fixed_step_s=10.0e-6,
    )
end


@testset "independent quadrature phase-shifter limit" begin
    ratio = 0.15
    lead = independent_quadrature_phase_shift_rad(ratio, 1)
    lag = independent_quadrature_phase_shift_rad(ratio, -1)
    @test lead == -lag
    @test tan(lead) ≈ ratio rtol=2eps(Float64)
    lead_power = independent_quadrature_phase_shifter_power_w(
        400.0,
        10.0,
        0.0,
        ratio,
        1,
    )
    lag_power = independent_quadrature_phase_shifter_power_w(
        400.0,
        10.0,
        0.0,
        ratio,
        -1,
    )
    @test lead_power == -lag_power
    @test lead_power > 0.0
    @test_throws ArgumentError independent_quadrature_phase_shift_rad(ratio, 0)
end

@testset "independent STATCOM power and DC-energy identities" begin
    phase_voltage = (sqrt(2.0) * 230.0, -sqrt(2.0) * 115.0, -sqrt(2.0) * 115.0)
    active_current = (10.0, -5.0, -5.0)
    reactive_current = (0.0, 5sqrt(3.0), -5sqrt(3.0))
    active = independent_statcom_instantaneous_power(
        phase_voltage,
        active_current,
    )
    reactive = independent_statcom_instantaneous_power(
        phase_voltage,
        reactive_current,
    )
    @test independent_three_phase_instantaneous_power(
        phase_voltage,
        active_current,
    ) == active
    @test active.active_w ≈ sum(phase_voltage .* active_current) rtol=2eps(Float64)
    @test active.reactive_var ≈ 0.0 atol=1.0e-12
    @test reactive.active_w ≈ 0.0 atol=1.0e-12
    @test reactive.reactive_var < 0.0
    capacitance = 5.0e-3
    voltage = 800.0
    @test independent_dc_link_energy_j(capacitance, voltage) == 1_600.0
    @test independent_statcom_dc_link_energy_j(capacitance, voltage) == 1_600.0
    @test_throws ArgumentError independent_statcom_dc_link_energy_j(0.0, voltage)
    derivative = -25.0
    ac_power = 8_000.0
    loss = 400.0
    dc_power = ac_power + loss + capacitance * voltage * derivative
    @test independent_statcom_dc_energy_residual_w(
        dc_power,
        ac_power,
        loss,
        capacitance,
        voltage,
        derivative,
    ) ≈ 0.0 atol=1.0e-12
    @test_throws ArgumentError independent_statcom_dc_energy_residual_w(
        dc_power,
        ac_power,
        -1.0,
        capacitance,
        voltage,
        derivative,
    )
end

@testset "independent LCC-HVDC limits and DC-link recurrence" begin
    line_voltage = 400.0
    no_load = independent_lcc_six_pulse_no_load_voltage_v(line_voltage)
    @test no_load ≈ 3sqrt(2.0) * line_voltage / pi
    rectifier = independent_lcc_six_pulse_average_voltage_v(
        line_voltage,
        20pi / 180.0,
        2.0e-3,
        20.0,
        50.0,
    )
    inverter = independent_lcc_six_pulse_average_voltage_v(
        line_voltage,
        145pi / 180.0,
        2.0e-3,
        20.0,
        50.0,
    )
    @test rectifier > 0.0
    @test inverter < 0.0
    @test independent_lcc_extinction_angle_rad(145pi / 180.0, 5pi / 180.0) ≈
        30pi / 180.0
    @test independent_lcc_vdcol_current_order_a(
        [0.0, 100.0, 500.0],
        [5.0, 10.0, 20.0],
        300.0,
    ) ≈ 15.0
    monopole = independent_lcc_hvdc_trace(
        pulse_count=6,
        pole_polarities=(1,),
        ac_line_line_rms_voltage_v=line_voltage,
        source_frequency_hz=50.0,
        rectifier_firing_angle_rad=20pi / 180.0,
        inverter_firing_angle_rad=145pi / 180.0,
        commutating_inductance_h=2.0e-3,
        smoothing_and_line_resistance_ohm=2.75,
        smoothing_and_line_inductance_h=40.0e-3,
        initial_pole_current_a=0.0,
        vdcol_voltage_breakpoints_v=[0.0, 100.0, 500.0],
        vdcol_current_breakpoints_a=[5.0, 10.0, 20.0],
        stop_time_s=0.5e-3,
        fixed_step_s=10.0e-6,
    )
    @test length(monopole.time_s) == 51
    @test size(monopole.pole_current_a) == (1, 51)
    @test all(isfinite, monopole.pole_current_a)
    @test all(>=(0.0), monopole.smoothing_energy_j)
    bipole = independent_lcc_hvdc_trace(
        pulse_count=12,
        pole_polarities=(1, -1),
        ac_line_line_rms_voltage_v=line_voltage,
        source_frequency_hz=50.0,
        rectifier_firing_angle_rad=20pi / 180.0,
        inverter_firing_angle_rad=145pi / 180.0,
        commutating_inductance_h=2.0e-3,
        smoothing_and_line_resistance_ohm=2.75,
        smoothing_and_line_inductance_h=40.0e-3,
        initial_pole_current_a=0.0,
        vdcol_voltage_breakpoints_v=[0.0, 100.0, 500.0],
        vdcol_current_breakpoints_a=[5.0, 10.0, 20.0],
        stop_time_s=0.5e-3,
        fixed_step_s=10.0e-6,
    )
    @test bipole.pole_current_a[1, :] == -bipole.pole_current_a[2, :]
    @test all(iszero, bipole.metallic_return_current_a)
    @test independent_lcc_pole_balance_residual_a(20.0, -20.0, 0.0) == 0.0
end
