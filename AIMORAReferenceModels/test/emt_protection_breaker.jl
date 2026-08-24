@testset "independent EMT protection and breaker formulations" begin
    instantaneous = independent_magnitude_timer_trace(
        [4.0, 5.0, 4.6, 4.4];
        tick_s=1.0e-3,
        pickup=5.0,
        dropout_ratio=0.9,
    )
    @test !instantaneous[1].operated
    @test instantaneous[2].operated
    @test instantaneous[3].operated
    @test !instantaneous[4].operated

    inverse = independent_magnitude_timer_trace(
        fill(10.0, 101);
        tick_s=0.01,
        pickup=5.0,
        dropout_ratio=0.9,
        timer_mode=:inverse,
        inverse_a=1.0,
        inverse_b=0.0,
        inverse_p=1.0,
        time_dial_s=1.0,
    )
    @test inverse[end].operated
    @test inverse[end].timer_fraction == 1.0

    @test independent_directional_torque(100.0, 10.0, 0.0) == 1_000.0
    @test independent_directional_torque(100.0, -10.0, 0.0) == -1_000.0
    mho = independent_mho_margin(50.0, 10.0, 5.0, 5.0)
    @test mho.asserted
    @test mho.margin_ohm == 5.0
    polygon = independent_polygon_margin(
        40.0 + 20.0im,
        10.0,
        ComplexF64[1.0, -1.0, 1.0im, -1.0im],
        [10.0, 0.0, 5.0, 5.0],
    )
    @test polygon.asserted
    @test polygon.impedance_ohm == 4.0 + 2.0im

    external = independent_biased_differential(
        [10.0, -10.0];
        minimum_operate_a=1.0,
        restraint_breakpoints_a=[10.0],
        region_slopes=[0.2, 0.5],
    )
    internal = independent_biased_differential(
        [10.0, 5.0];
        minimum_operate_a=1.0,
        restraint_breakpoints_a=[10.0],
        region_slopes=[0.2, 0.5],
    )
    @test !external.asserted
    @test internal.asserted
    @test internal.threshold_current_a == 1.5

    rocof = independent_rocof_trace([50.0, 49.9, 49.8], 0.01, 2)
    @test rocof[1:2] == [nothing, nothing]
    @test rocof[3] ≈ -10.0 atol=1.0e-12
    wave = only(independent_incremental_wave_trace([100.0, 110.0], [5.0, 6.0], 10.0))
    @test wave.forward_wave_v == 20.0
    @test wave.reverse_wave_v == 0.0

    deliveries = independent_protection_message_calendar(
        [(payload=:permissive, send_tick=0),
         (payload=:blocking, send_tick=0),
         (payload=:direct_trip, send_tick=1)];
        fixed_delay_ticks=2,
        dropped_sequences=Set([2]),
        duplicate_copies=Dict(3 => 2),
        additional_delay_ticks=Dict(3 => 2),
    )
    @test getfield.(deliveries, :delivery_tick) == [2, 5, 5]
    @test getfield.(deliveries, :copy_index) == [1, 1, 2]

    @test independent_breaker_load_voltage(100.0, 0.1, 1.0e6, 0.1) ≈ 50.0 rtol=1.0e-7
    @test independent_breaker_load_voltage(100.0, 0.1, 1.0e-9, 0.1) ≈ 1.0e-6 rtol=1.0e-7
    energy = independent_contact_energy_trace([100.0, 50.0, 0.0], [10.0, 5.0, 0.0], 1.0e-3)
    @test energy.energy_j == [0.0, 0.625, 0.75]
    @test independent_breaker_failure(0, 3, 3, (false, false, false), (10.0, 0.0, 0.0), 1.0).failed
    @test !independent_breaker_failure(0, 3, 3, (true, true, true), (0.0, 0.0, 0.0), 1.0).failed
end
