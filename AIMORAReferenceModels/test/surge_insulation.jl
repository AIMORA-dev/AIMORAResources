@testset "independent surge and insulation formulations" begin
    double_exponential = independent_double_exponential_lightning(0.0, 30.0e3, 1.0e4, 1.0e6)
    @test double_exponential.current_a == 0.0
    at_peak = independent_double_exponential_lightning(
        double_exponential.peak_time_s,
        30.0e3,
        1.0e4,
        1.0e6,
    )
    @test at_peak.current_a ≈ 30.0e3 rtol=2.0e-14
    integrals = independent_double_exponential_integrals(30.0e3, 1.0e4, 1.0e6)
    @test integrals.charge_c > 0.0
    @test integrals.specific_energy_a2s > 0.0

    heidler = independent_heidler_lightning(0.0, -20.0e3, 1.0e-6, 50.0e-6, 2.0)
    @test heidler.current_a == -0.0
    heidler_peak = independent_heidler_lightning(
        heidler.peak_time_s,
        -20.0e3,
        1.0e-6,
        50.0e-6,
        2.0,
    )
    @test heidler_peak.current_a ≈ -20.0e3 rtol=2.0e-13

    combined_arc = independent_combined_arc_step(
        10.0,
        100.0,
        1.0e-6;
        cassie_power_w=2.0e5,
        mayr_power_w=2.0e3,
        cassie_time_constant_s=20.0e-6,
        mayr_time_constant_s=5.0e-6,
        transition_power_w=2.0e4,
        minimum_conductance_s=1.0e-9,
        maximum_conductance_s=1.0e6,
    )
    @test combined_arc.conductance_s > 0.0
    @test combined_arc.current_a == 100.0 * combined_arc.conductance_s
    fault_arc = independent_fault_arc_step(
        1.0,
        100.0,
        1.0e-6;
        cooling_power_w=1.0e3,
        time_constant_s=10.0e-6,
        minimum_conductance_s=1.0e-9,
        maximum_conductance_s=1.0e5,
    )
    @test fault_arc.conductance_s > 1.0

    vacuum = independent_vacuum_surfaces(
        :open,
        0.0,
        150.0,
        2.0e-6;
        separation_time_s=0.0,
        chopping_current_a=5.0,
        initial_dielectric_strength_v=10.0,
        dielectric_recovery_rate_v_per_s=50.0e6,
        maximum_dielectric_strength_v=1.0e3,
    )
    @test vacuum.dielectric_strength_v == 110.0
    @test vacuum.restrike_surface_v == 40.0

    metal_oxide = independent_metal_oxide_characteristic(
        [1.0, 10.0, 100.0],
        [100.0, 120.0, 140.0],
        -120.0,
    )
    @test metal_oxide.current_a ≈ -10.0 rtol=2.0e-14
    @test metal_oxide.derivative_s > 0.0
    duty = independent_arrester_duty_step(
        100.0,
        10.0,
        120.0,
        20.0,
        1.0e-3;
        temperature_k=300.0,
        ambient_temperature_k=293.15,
        thermal_capacitance_j_per_k=100.0,
        thermal_resistance_k_per_w=10.0,
    )
    @test duty.charge_increment_c == 0.015
    @test duty.energy_increment_j == 1.7
    @test duty.temperature_k > 300.0

    ground_dc = independent_positive_real_grounding(0.0, 0.02, [100.0], [0.01])
    @test ground_dc.admittance_s == 0.02 + 0.0im
    ground_ac = independent_positive_real_grounding(1.0e6, 0.02, [100.0], [0.01])
    @test real(ground_ac.admittance_s) > real(ground_dc.admittance_s)
    ionized = independent_ionizing_ground_step(
        0.1,
        20.0e3,
        1.0e-6;
        linear_resistance_ohm=10.0,
        electrode_radius_m=0.1,
        maximum_ionized_radius_m=1.0,
        critical_field_v_per_m=100.0e3,
        expansion_rate_m_per_v_s=1.0,
        recovery_rate_per_s=10.0,
    )
    @test ionized.radius_m > 0.1
    @test ionized.current_a > 2.0e3

    impedance = [100.0 10.0; 10.0 120.0]
    voltage = [20.0, -10.0]
    current = [0.1, -0.2]
    waves = independent_traveling_wave_state(impedance, voltage, current)
    @test waves.forward_voltage_v + waves.reverse_voltage_v ≈ voltage
    @test waves.reconstructed_current_a ≈ current
    reflection = independent_traveling_wave_reflection([100.0;;], [200.0;;], [30.0])
    @test reflection.reflected_voltage_v ≈ [10.0]
    @test reflection.transmitted_voltage_v ≈ [40.0]

    effect = independent_disruptive_effect_step(
        0.0,
        0.0,
        200.0,
        -300.0,
        1.0e-6;
        positive_threshold_voltage_v=100.0,
        negative_threshold_voltage_v=100.0,
        positive_exponent=1.0,
        negative_exponent=1.0,
    )
    @test effect.positive ≈ 50.0e-6 atol=1.0e-20
    @test effect.negative ≈ 100.0e-6 rtol=2.0e-16
    leader = independent_leader_progression_step(
        0.0,
        200.0e3,
        200.0e3,
        1.0e-6;
        gap_length_m=1.0,
        positive_inception_field_v_per_m=100.0e3,
        negative_inception_field_v_per_m=120.0e3,
        positive_velocity_coefficient=1.0,
        negative_velocity_coefficient=1.0,
        velocity_exponent=1.0,
    )
    @test leader.length_m ≈ 0.1 atol=1.0e-16
    @test leader.polarity == 1
    @test leader.incepted

    corona = independent_corona_charge(
        -150.0,
        false;
        base_capacitance_f=1.0e-9,
        incremental_capacitance_f_per_v=1.0e-12,
        onset_voltage_v=100.0,
        extinction_voltage_v=80.0,
    )
    @test corona.active
    @test corona.charge_c < 0.0
    @test corona.differential_capacitance_f > 1.0e-9
    gis = independent_gis_gil_matrices(
        [1.0e-4 0.0; 0.0 1.0e-4],
        [1.0e-6 0.2e-6; 0.2e-6 1.0e-6],
        zeros(2, 2),
        [50.0e-12 -10.0e-12; -10.0e-12 50.0e-12],
        10.0,
        1.0e6,
    )
    @test isapprox(real(gis.series_impedance_ohm[1, 1]), 1.0e-3)
    @test imag(gis.series_impedance_ohm[1, 2]) > 0.0
    @test imag(gis.shunt_admittance_s[1, 2]) < 0.0

    interval = independent_wilson_interval(10, 100, 1.959963984540054)
    @test interval.probability == 0.1
    @test interval.lower < interval.probability < interval.upper
    @test independent_wilson_interval(0, 100, 1.959963984540054).lower == 0.0
end
