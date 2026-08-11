#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.Branches
using AIMORA.EMTStudy
using AIMORA.Lines
using AIMORA.Nodal
using AIMORA.Sources
using .ExampleSupport

const DT_S = 50e-6

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    propagation_terms = [
        SemlyenRationalTerm(15_161.0, 0.75119),
        SemlyenRationalTerm(1_710.5, 0.24881),
    ]
    admittance_terms = [
        SemlyenRationalTerm(595.84, -0.0011954),
        SemlyenRationalTerm(39_933.0, -0.00074162),
    ]
    mode = SemlyenModeParameters(
        5e-3,
        2.3 * DT_S,
        1.0 + 0.2im,
        0.01 + 0.002im,
        60.0,
        propagation_terms,
        admittance_terms,
    )
    line = semlyen_frequency_dependent_line(
        [1],
        [2],
        [mode],
        ones(1, 1),
        ones(1, 1),
        DT_S,
    )
    checks = semlyen_line_physical_checks([mode], ones(1, 1), ones(1, 1))
    system = NodalSystem(2, [
        sinusoidal_thevenin_source(1, 1e6, 1.0, 60.0),
        line,
        ConductanceBranch(2, 0, 5e-3),
    ])
    context = initialize_step_context(
        system;
        node_map = Dict(:sending => 1, :receiving => 2),
        element_names = [:source, :semlyen_line, :load],
        dt_s = DT_S,
        t_end_s = 20e-3,
        source = "frequency-dependent line example",
    )
    trace = run_deck_emt(context)
    sending = vec(trace.voltage_pu[trace.node_map[:sending], :])
    receiving = vec(trace.voltage_pu[trace.node_map[:receiving], :])
    waveform_csv = write_series_csv(
        joinpath(output_dir, "line_waveform.csv"),
        "time_s",
        trace.time_s,
        ["sending_v_pu" => sending, "receiving_v_pu" => receiving],
    )
    waveform_svg = write_waveform_svg(
        joinpath(output_dir, "line_waveform.svg"),
        trace.time_s,
        ["sending_v_pu" => sending, "receiving_v_pu" => receiving];
        title = "Frequency-Dependent Line Voltages",
        y_label = "voltage (pu)",
    )

    frequencies_hz = 10.0 .* 10.0 .^ range(0.0, 3.0; length = 121)
    response = ComplexF64[
        sum(
            term.residue * term.pole /
            (term.pole + 2.0im * pi * frequency)
            for term in propagation_terms
        )
        for frequency in frequencies_hz
    ]
    response_magnitude = abs.(response)
    frequency_csv = write_series_csv(
        joinpath(output_dir, "frequency_response.csv"),
        "frequency_hz",
        frequencies_hz,
        ["propagation_magnitude" => response_magnitude],
    )
    frequency_svg = write_waveform_svg(
        joinpath(output_dir, "frequency_response.svg"),
        frequencies_hz,
        ["propagation_magnitude" => response_magnitude];
        title = "Semlyen Propagation Response",
        x_label = "frequency (Hz)",
        y_label = "magnitude",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Frequency-Dependent Semlyen Line",
        (
            timestep_s = DT_S,
            travel_time_s = mode.travel_time_s,
            update_count = line.update_count,
            transform_inverse_error = checks.transform_inverse_max_abs_error,
            minimum_phase_admittance_eigenvalue =
                checks.phase_admittance_minimum_eigenvalue,
            physical_checks_passed = checks.physical_checks_passed,
            julia_only = true,
        ),
    )
    @printf("Waveform: %s, %s\n", waveform_csv, waveform_svg)
    @printf("Frequency response: %s, %s\n", frequency_csv, frequency_svg)
    @printf("Summary: %s\n", summary_path)
end

main()
