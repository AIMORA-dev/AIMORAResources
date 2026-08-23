@testset "independent local exponential-history subcycling" begin
    reference = independent_exponential_history_subcycle(
        pole_per_s=15_161.0,
        residue=0.75119,
        network_step_s=20.0e-6,
        local_substeps=4,
        previous_state=0.25,
        previous_input=-3.0,
        endpoint_input=7.0,
    )
    @test reference.time_s == collect(0:4) .* 5.0e-6
    @test reference.input == ComplexF64[-3.0, -0.5, 2.0, 4.5, 7.0]
    @test reference.state[1] == 0.25
    @test reference.state[end] ≈ reference.exact_endpoint_state atol=2.0e-15
    @test reference.endpoint_identity_error <= 2.0e-15
    @test abs(reference.state[end - 1] - reference.exact_endpoint_state) > 1.0e-3
    @test_throws ArgumentError independent_exponential_history_subcycle(
        pole_per_s=-1.0,
        residue=1.0,
        network_step_s=1.0e-3,
        local_substeps=4,
    )
end

@testset "independent one-pass causal lagged exchange" begin
    step_s = 1.0e-6
    exchange_impedance_ohm = 0.5 * (
        0.8 + 2.0 * 0.015 / step_s +
        inv(inv(12.0) + 2.0 * 2.0e-4 / step_s)
    )
    reference = independent_lagged_passive_rlc(
        start_time_s=0.0,
        stop_time_s=4.0e-6,
        communication_step_s=step_s,
        source_amplitude_v=120.0,
        source_frequency_hz=60.0,
        source_resistance_ohm=0.8,
        source_inductance_h=0.015,
        load_resistance_ohm=12.0,
        load_capacitance_f=2.0e-4,
        reference_impedance_ohm=exchange_impedance_ohm,
        voltage_base_v=120.0,
        communication_error_absolute_v=1.0e-6,
        communication_error_relative=5.0e-2,
    )
    @test reference.time_s == collect(0:4) .* step_s
    @test all(reference.communication_accepted)
    @test all(==(step_s), reference.interface_value_age_s)
    @test all(diff(reference.interface_current_a) .>= 0.0)
    @test last(reference.interface_current_a) > 0.0
    @test reference.communication_error_estimate_v ==
        abs.(reference.voltage_residual_v)
    future_sample_mutation = copy(reference.interface_current_a)
    future_sample_mutation[2] = future_sample_mutation[3]
    @test future_sample_mutation != reference.interface_current_a
end
