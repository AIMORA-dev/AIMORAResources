#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

import AIMORA
using AIMORA.EMTStudy
using AIMORA.ReportArtifacts
using .ExampleSupport

const DECK_LINES = [
    # This is the accepted small Julia deck subset, not full BPA EMTP deck execution.
    "source src bus1 1.0e9 0.0 60.0 0.0 1.0",
    "resistor line bus1 bus2 1.0",
    "resistor load bus2 0 1.0",
    "time_switch tie bus2 bus3 0.00004 1.0 false 1.0e9 0.0",
    "resistor load3 bus3 0 1.0",
]

const GROUNDED_REFERENCE_DECK_LINES = [
    "BEGIN NEW DATA CASE",
    "POWER FREQUENCY                     60.0",
    "ABSOLUTE U.M. DIMENSIONS              20       2      50      60",
    "C PRINTED NUMBER WIDTH  13  2",
    " .000200    .100",
    "       1       1       1       1       1      -1                               1",
    "       5       5      20      20     100     100",
    "C BRANCHES",
    "  BUSAS2                  1.0E+6",
    "  BUSBS2      BUSAS2",
    "  BUSCS2      BUSAS2",
    "BLANK card ending branch cards",
    "BLANK card ending nonexistent switch cards",
    "BLANK card ending all electric-network sources",
    "BLANK card terminating output variable requests",
    "BLANK card terminating plot cards",
    "BEGIN NEW DATA CASE",
]

function write_grounded_reference_artifacts(output_dir)
    parsed = AIMORA.DeckParser.parse_deck_lines(
        GROUNDED_REFERENCE_DECK_LINES;
        source = "grounded scalar branch reference example",
    )
    AIMORA.ValidationCore.is_valid(parsed.validation) ||
        error("grounded scalar reference deck did not validate")
    length(parsed.elements) == 3 ||
        error("expected three grounded conductance branches")

    conductance_s = getfield.(parsed.elements, :g)
    branch_index = collect(eachindex(conductance_s))
    series = ["conductance_s" => conductance_s]
    csv_path = write_series_csv(
        joinpath(output_dir, "grounded_scalar_branch_references.csv"),
        "branch_index",
        branch_index,
        series,
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "grounded_scalar_branch_references.svg"),
        branch_index,
        series;
        title = "Inherited Grounded Scalar Branch Conductance",
        x_label = "branch index",
        y_label = "conductance (S)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "grounded_scalar_branch_references.md"),
        "Grounded Scalar Branch References",
        (
            parsed_branches = length(parsed.elements),
            explicit_conductance_s = conductance_s[1],
            inherited_conductance_s = conductance_s[2],
            second_inherited_conductance_s = conductance_s[3],
            fixed_reference_rows = get(
                parsed.card_counts,
                :fixed_grounded_scalar_branch_reference,
                0,
            ),
        ),
    )
    return (; csv_path, svg_path, summary_path)
end

function main()
    output_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "outputs")
    mkpath(output_dir)

    dt_s = 20.0e-6
    t_end_s = 100.0e-6
    trace = run_deck_emt(DECK_LINES; dt_s = dt_s, t_end_s = t_end_s, source = "parsed_deck_trace example")
    artifacts = write_deck_trace_report_artifacts(
        output_dir,
        trace;
        basename = "parsed_deck_trace",
        title = "Parsed Deck Trace",
    )
    summary_path = write_deck_trace_summary(joinpath(output_dir, "parsed_deck_trace_summary.json"), trace)
    grounded_artifacts = write_grounded_reference_artifacts(output_dir)
    result = deck_trace_result(trace)

    @printf("Output CSV: %s\n", abspath(artifacts.csv_path))
    @printf("Output summary: %s\n", abspath(summary_path))
    @printf("Output EMTP-style report: %s\n", abspath(artifacts.text_path))
    @printf("Output SVG: %s\n", abspath(artifacts.svg_path))
    @printf("Output report manifest: %s\n", abspath(artifacts.manifest_path))
    @printf("Output OVER20 finalization CSV: %s\n", abspath(artifacts.finalization_csv_path))
    @printf("Output OVER20 finalization report: %s\n", abspath(artifacts.finalization_text_path))
    @printf("Output OVER20 finalization manifest: %s\n", abspath(artifacts.finalization_manifest_path))
    @printf("Grounded-reference CSV: %s\n", grounded_artifacts.csv_path)
    @printf("Grounded-reference SVG: %s\n", grounded_artifacts.svg_path)
    @printf("Grounded-reference summary: %s\n", grounded_artifacts.summary_path)
    @printf("Engine: Julia fixed-step parsed-deck subset runner\n")
    @printf("Legacy Fortran in loop: no\n")
    @printf("Full BPA EMTP deck execution: no\n")
    @printf("Result status: %s\n", String(result.status))
    @printf("Samples: %d, dt: %.1f us\n", result.quantities[:samples].value, trace.dt_s * 1.0e6)
    @printf("Final bus2 voltage: %.6f pu\n", final_voltage_pu(trace, :bus2))
    @printf("Final bus3 voltage: %.6f pu\n", final_voltage_pu(trace, :bus3))
end

main()
