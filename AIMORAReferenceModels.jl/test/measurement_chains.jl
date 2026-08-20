using LinearAlgebra

@testset "independent instrument and measurement-chain formulations" begin
    resistance = [0.1 0.0; 0.0 0.2]
    inductance = [0.2 0.18; 0.18 0.2]
    instrument = independent_instrument_transformer_trapezoidal_step(
        zeros(2),
        zeros(2),
        [2.0, 0.0],
        resistance,
        inductance,
        10.0e-6;
        winding_turns=[1.0, 10.0],
    )
    @test maximum(abs, instrument.constitutive_residual_vs) <= 2.0e-16
    @test abs(instrument.energy_residual_j) <= 2.0e-16
    @test instrument.stored_energy_j >= 0.0
    @test all(isfinite, instrument.current_a)

    equivalent_capacitance = inv(inv(1.0e-9) + inv(10.0e-9))
    compensation_inductance = inv((2.0 * pi * 50.0)^2 * equivalent_capacitance)
    cvt = independent_cvt_metrics(
        1.0e-9,
        10.0e-9,
        compensation_inductance;
        line_voltage_v=100.0,
        divider_voltage_v=10.0,
        electromagnetic_primary_voltage_v=9.0,
        compensation_current_a=0.01,
        suppression_capacitance_f=1.0e-9,
    )
    @test cvt.divider_ratio == 1.0 / 11.0
    @test cvt.series_resonance_hz ≈ 50.0
    @test cvt.stored_energy_j > 0.0

    timestep = 0.1
    series_current = 0.05 / 1.05
    cvt_residuals = independent_cvt_trapezoidal_residuals(
        reshape([1.0, 1.0, 1.0], 1, 3),
        [:capacitance, :series_rl, :resistance],
        [0.0, 1.0, 2.0],
        [0.0, 1.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0],
        [1.0],
        zeros(3),
        [20.0, series_current, 0.5],
        timestep,
    )
    @test maximum(abs, cvt_residuals.constitutive_residual) <= 2.0e-16
    @test cvt_residuals.kcl_residual_a == [20.5 + series_current]
    @test cvt_residuals.stored_energy_j > 0.0
    @test cvt_residuals.dissipated_power_w > 0.0

    filter_step = independent_analog_filter_trapezoidal_step(
        [0.0],
        0.0,
        1.0,
        reshape([-10.0], 1, 1),
        [10.0],
        [1.0],
        0.0,
        0.01,
    )
    @test filter_step.state[1] ≈ 0.05 / 1.05
    @test filter_step.output == filter_step.state[1]
    @test maximum(abs, filter_step.residual) <= 2.0e-17

    quantized = independent_uniform_measurement_quantizer(
        [0.5, 1.5, -0.5, -1.5, 20.0];
        lower_limit=-10.0,
        upper_limit=10.0,
        engineering_step=1.0,
        minimum_code=-10,
        maximum_code=10,
        tie_rule=:ties_to_even,
    )
    @test quantized.codes == [0, 2, 0, -2, 10]
    @test quantized.engineering_values == Float64[0, 2, 0, -2, 10]
    @test quantized.clipped == BitVector([false, false, false, false, true])

    tick_s = 1.0e-4
    times = tick_s .* collect(0:500)
    analog = hcat(
        100.0 .* cos.(2.0 * pi * 50.0 .* times),
        100.0 .* cos.(2.0 * pi * 50.0 .* times .- 2.0 * pi / 3.0),
        100.0 .* cos.(2.0 * pi * 50.0 .* times .+ 2.0 * pi / 3.0),
    )
    samples = independent_measurement_acquisition(
        analog,
        tick_s;
        sample_period_ticks=1,
        delay_ticks=2,
        lower_limit=-200.0,
        upper_limit=200.0,
        engineering_step=0.001,
        minimum_code=-200_000,
        maximum_code=200_000,
        window_weights_newest_first=ones(200),
        nominal_frequency_hz=50.0,
        phase_order=[:a, :b, :c],
        positive_sequence_threshold=1.0e-6,
        frequency_update_separation=1,
    )
    @test length(samples) == 499
    @test first(samples).source_tick == 0
    @test first(samples).release_tick == 2
    @test samples[200].quality == :frequency_unavailable
    @test samples[201].quality == :valid
    @test last(samples).frequency_hz ≈ 50.0 atol=2.0e-8
    @test last(samples).sliding_rms ≈ fill(100.0 / sqrt(2.0), 3) atol=5.0e-4
    @test abs(last(samples).sequence_phasors.positive) ≈ 100.0 / sqrt(2.0) atol=5.0e-4
    @test abs(last(samples).sequence_phasors.negative) <= 5.0e-4

    raw = [1 -2; 3 4]
    digital = Bool[true false true; false true false]
    ascii = independent_comtrade_ascii_bytes([1, 2], [0, 50], raw, digital)
    @test String(ascii) == "1,0,1,-2,1,0,1\n2,50,3,4,0,1,0\n"
    binary = independent_comtrade_binary32_bytes([1, 2], [0, 50], raw, digital)
    @test length(binary) == 2 * (8 + 2 * 4 + 2)
    @test binary[1:8] == UInt8[1, 0, 0, 0, 0, 0, 0, 0]
    @test binary[9:12] == UInt8[1, 0, 0, 0]
    @test binary[13:16] == UInt8[0xfe, 0xff, 0xff, 0xff]
    @test binary[17:18] == UInt8[0x05, 0x00]
    scaled = independent_comtrade_scale_and_time(
        raw,
        [0.5, -2.0],
        [1.0, 0.0],
        [0, 50],
        1.0,
    )
    @test scaled.engineering_values == [1.5 4.0; 2.5 -8.0]
    @test scaled.time_s ≈ [0.0, 50.0e-6]
    @test occursin(r"^[0-9a-f]{64}$", independent_comtrade_signature("cfg\n", binary))
end
