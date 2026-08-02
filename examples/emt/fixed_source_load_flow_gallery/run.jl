#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using .ExampleSupport

const CASES = (
    (name = :angle_q, file = "fix_source_angle_q.deck"),
    (
        name = :automatic_separately_excited_dc_machine,
        file = "fix_source_automatic_separately_excited_dc_machine.deck",
    ),
    (name = :cage_induction_machine, file = "fix_source_cage_induction_machine.deck"),
    (name = :controlled_switch, file = "fix_source_controlled_switch.deck"),
    (name = :coupled_phase_pi, file = "fix_source_coupled_phase_pi.deck"),
    (name = :coupled_sequence, file = "fix_source_coupled_sequence.deck"),
    (name = :distributed_line, file = "fix_source_distributed_line.deck"),
    (name = :induction_machine, file = "fix_source_induction_machine.deck"),
    (name = :initial_switch, file = "fix_source_initial_switch.deck"),
    (name = :scalar_load_flow, file = "fix_source_load_flow.deck"),
    (
        name = :single_phase_induction_machine,
        file = "fix_source_single_phase_induction_machine.deck",
    ),
    (name = :three_phase_pv, file = "fix_source_three_phase_pv.deck"),
    (
        name = :two_phase_induction_machine,
        file = "fix_source_two_phase_induction_machine.deck",
    ),
    (
        name = :two_phase_rotor_induction_machine,
        file = "fix_source_two_phase_rotor_induction_machine.deck",
    ),
    (
        name = :two_phase_synchronous_machine,
        file = "fix_source_two_phase_synchronous_machine.deck",
    ),
    (
        name = :wound_field_synchronous_machine,
        file = "fix_source_wound_field_synchronous_machine.deck",
    ),
    (
        name = :saturated_wound_field_synchronous_machine,
        file = "fix_source_wound_field_synchronous_machine_saturated.deck",
    ),
)

function maximum_absolute(values)
    isempty(values) && return 0.0
    return maximum(abs, values)
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    results = NamedTuple[]
    for case in CASES
        input_path = joinpath(@__DIR__, "decks", case.file)
        parsed = parse_example_deck(input_path)
        assert_deck_valid!(parsed)
        result = deck_fixed_source_load_flow(parsed)
        result.converged || error("$(case.name) FIX SOURCE case did not converge")
        report_path = joinpath(output_dir, "$(case.name)_report.txt")
        open(report_path, "w") do io
            write_fixed_source_load_flow_report(io, result)
        end
        push!(results, (
            name = case.name,
            file = case.file,
            result,
            maximum_voltage = maximum(abs, result.node_voltage_phasors),
            maximum_p_mismatch =
                maximum_absolute(result.constraint_active_power_mismatches),
            maximum_q_mismatch =
                maximum_absolute(result.constraint_reactive_power_mismatches),
        ))
    end
    case_index = collect(eachindex(results))
    voltage = [row.maximum_voltage for row in results]
    csv_path = joinpath(output_dir, "fixed_source_metrics.csv")
    open(csv_path, "w") do io
        println(io, "case,input,converged,iterations,network_topologies,maximum_voltage_peak,maximum_p_mismatch,maximum_q_mismatch")
        for row in results
            @printf(
                io,
                "%s,%s,%s,%d,%s,%.12g,%.12g,%.12g\n",
                String(row.name),
                row.file,
                row.result.converged,
                row.result.iteration_count,
                join(String.(row.result.network_topology_kinds), "+"),
                row.maximum_voltage,
                row.maximum_p_mismatch,
                row.maximum_q_mismatch,
            )
        end
    end
    plot_path = write_waveform_svg(
        joinpath(output_dir, "fixed_source_voltage.svg"),
        case_index,
        ["maximum_voltage_peak" => voltage];
        title = "FIX SOURCE Solved Voltage by Topology",
        x_label = "case index (see fixed_source_metrics.csv)",
        y_label = "peak voltage",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "FIX SOURCE Load-Flow Gallery",
        (
            julia_only = true,
            case_count = length(results),
            all_converged = all(row -> row.result.converged, results),
            topologies = join(
                unique(vcat(
                    (String.(row.result.network_topology_kinds) for row in results)...,
                )),
                ", ",
            ),
            interpretation =
                "All 17 source-constraint, switch, line, and machine-boundary variants converge before EMT initialization.",
        ),
    )
    @printf("Metrics: %s\n", abspath(csv_path))
    @printf("Plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
