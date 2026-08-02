#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.EMTStudy
using AIMORA.Sources
using .ExampleSupport

const INPUT_PATH = joinpath(@__DIR__, "source_signals.csv")

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    table = TabulatedSourceSignalProvider(INPUT_PATH; extrapolation = :hold)
    analytic = AnalyticSourceSignal(13, 1.0, 5e-3, -50.0, 0.0, nextfloat(20e-3))
    program = SourceSignalProgram(
        table,
        [AnalyticSourceSlot(2, analytic; assignment = :replace, unit = :V)],
    )
    time_s = collect(0.0:0.25e-3:20e-3)
    slot_1 = Float64[]
    slot_2 = Float64[]
    for time in time_s
        interpolated = source_signal_values(program, zeros(10), time)
        accepted = source_signal_analytic_values(program, interpolated, time)
        push!(slot_1, accepted.values[1])
        push!(slot_2, accepted.values[2])
    end
    series = ["slot_1_tabulated" => slot_1, "slot_2_analytic" => slot_2]
    csv_path = write_series_csv(
        joinpath(output_dir, "source_program.csv"),
        "time_s",
        time_s,
        series,
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "source_program.svg"),
        time_s,
        series;
        title = "Tabulated and Analytic Source Signals",
        y_label = "source value",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Tabulated and Analytic Source Program",
        (
            input_csv = portable_input_path(INPUT_PATH),
            interpolation = "linear with endpoint hold",
            analytic_equation = "ramp to 1.0 in 5 ms, then slope -50 per second",
            analytic_assignment = "replace source slot 2",
            sample_count = length(time_s),
            julia_only = true,
        ),
    )
    @printf("CSV: %s\n", csv_path)
    @printf("Waveform: %s\n", svg_path)
    @printf("Summary: %s\n", summary_path)
end

main()
