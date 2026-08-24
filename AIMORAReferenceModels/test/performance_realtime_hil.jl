@testset "independent performance and real-time formulations" begin
    admittance = [2.0 -1.0; -1.0 2.0]
    current = [1.0, 0.0]
    voltage = admittance \ current
    residual = independent_scaled_linear_residual(admittance, voltage, current)
    @test residual.residual == [0.0, 0.0]
    @test residual.scaled_norm == 0.0

    shuffled = [(index=3, value=:third), (index=1, value=:first), (index=2, value=:second)]
    @test independent_indexed_collection(shuffled, 3) == Any[:first, :second, :third]
    @test_throws ArgumentError independent_indexed_collection(
        [(index=1, value=:first), (index=1, value=:duplicate)],
        2,
    )
    @test_throws ArgumentError independent_indexed_collection(
        [(index=1, value=:first)],
        2,
    )

    @test independent_realtime_release_ns(1_000, 20_000, 3) == 61_000
    timing = independent_realtime_metrics(1_000, 1_100, 22_000, 20_000)
    @test timing.jitter_ns == 100
    @test timing.computation_ns == 20_900
    @test timing.response_ns == 21_000
    @test timing.slack_ns == -1_000
    @test timing.overrun
    @test independent_affine_channel_value(3.0, 2.0, -1.0) == 5.0

    controller = independent_loopback_controller_step(0.0, 4.0, 0.25, 2.0)
    @test controller.state == 1.0
    @test controller.output == 2.0
    frames = [
        (sequence=UInt64(1), logical_time_ns=20_000, values=[1.0, 2.0], valid=true),
        (sequence=UInt64(2), logical_time_ns=40_000, values=[2.0, 3.0], valid=true),
    ]
    @test independent_realtime_replay_signature(frames) ==
        independent_realtime_replay_signature(copy(frames))
    @test independent_realtime_replay_signature(frames) !=
        independent_realtime_replay_signature(reverse(frames))
end
