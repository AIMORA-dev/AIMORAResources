#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.Sources
using .ExampleSupport

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    time_s = collect(0.0:25e-6:20e-3)
    tstop = last(time_s) + eps(last(time_s))
    sine = [sinusoidal_value(t, 1.0, 60.0) for t in time_s]
    dc = [analytic_source_value(11, 0.8, 0.0, 0.0, 0.0, tstop, t) for t in time_s]
    ramp = [analytic_source_value(12, 1.0, 5e-3, 0.0, 0.0, tstop, t) for t in time_s]
    ramp_slope = [
        analytic_source_value(13, 1.0, 5e-3, -20.0, 0.0, tstop, t)
        for t in time_s
    ]
    cosine = [
        analytic_source_value(14, 1.0, 0.0, 2.0 * pi * 60.0, 0.0, tstop, t)
        for t in time_s
    ]
    double_exponential = [
        analytic_source_value(15, 1.0, -1000.0, -100.0, 0.0, tstop, t)
        for t in time_s
    ]
    harmonic = [
        sin(2.0 * pi * 60.0 * t) +
        0.20 * sin(3.0 * 2.0 * pi * 60.0 * t) +
        0.10 * sin(5.0 * 2.0 * pi * 60.0 * t)
        for t in time_s
    ]
    series = [
        "sine_60hz" => sine,
        "dc" => dc,
        "ramp" => ramp,
        "ramp_then_slope" => ramp_slope,
        "cosine_60hz" => cosine,
        "double_exponential" => double_exponential,
        "harmonic_1_3_5" => harmonic,
    ]
    csv_path = write_series_csv(
        joinpath(output_dir, "source_waveforms.csv"),
        "time_s",
        time_s,
        series,
    )
    standard_plot = write_waveform_svg(
        joinpath(output_dir, "standard_source_waveforms.svg"),
        time_s,
        series[1:6];
        title = "AIMORA Analytic Source Waveforms",
        y_label = "source value",
    )
    harmonic_plot = write_waveform_svg(
        joinpath(output_dir, "harmonic_waveform.svg"),
        time_s,
        ["fundamental" => sine, "fundamental_plus_3rd_5th" => harmonic];
        title = "Custom Harmonic Source",
        y_label = "source value",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Source Waveform Gallery",
        (
            sample_count = length(time_s),
            timestep_s = time_s[2] - time_s[1],
            source_types = "sinusoid, DC, ramp, ramp/slope, cosine, double exponential, custom harmonics",
            harmonic_equation =
                "sin(ωt) + 0.20 sin(3ωt) + 0.10 sin(5ωt)",
        ),
    )

    @printf("CSV: %s\n", csv_path)
    @printf("Analytic source plot: %s\n", standard_plot)
    @printf("Harmonic plot: %s\n", harmonic_plot)
    @printf("Summary: %s\n", summary_path)
end

main()
