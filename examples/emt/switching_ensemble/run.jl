#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using AIMORACases
using .ExampleSupport

function write_schedules(path, schedules)
    open(path, "w") do io
        println(io, "energization,switch,event,time_s")
        for schedule in schedules
            for index in eachindex(schedule.switch_names)
                @printf(
                    io,
                    "%d,%s,%s,%.12g\n",
                    schedule.energization_index,
                    schedule.switch_names[index],
                    schedule.events[index],
                    schedule.event_times_s[index],
                )
            end
        end
    end
    return abspath(path)
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    parsed = parse_example_deck(AIMORACases.case_path(:emt_switching_transient))
    assert_deck_valid!(parsed)
    switch = only(deck_over5_switch_rows(parsed))
    rules = EMTSwitchTimingRule[
        EMTSwitchTimingRule(
            switch.name,
            :close;
            mode = :systematic,
            center_time_s = 50e-6,
            spread_s = 30e-6,
        ),
        EMTSwitchTimingRule(
            switch.name,
            :open;
            mode = :dependent,
            dependency_switch = switch.name,
            dependency_event = :close,
            dependency_delay_s = 20e-6,
        ),
    ]
    schedules = emt_switch_schedules(
        parsed;
        energization_count = 7,
        seed = 2026,
        timing_rules = rules,
    )
    ensemble = run_deck_emt_ensemble(
        parsed;
        seed = 2026,
        timing_rules = rules,
        schedules,
    )
    statistic = only(
        item for item in ensemble.channel_statistics
        if item.quantity_kind == :node_voltage && item.name == :BUS3
    )
    close_time_s = [schedule.event_times_s[1] for schedule in schedules]
    schedule_path = write_schedules(
        joinpath(output_dir, "switch_schedules.csv"),
        schedules,
    )
    extrema_path = write_series_csv(
        joinpath(output_dir, "ensemble_extrema.csv"),
        "closing_time_s",
        close_time_s,
        [
            "maximum_bus3_v_pu" => statistic.maximum_samples,
            "minimum_bus3_v_pu" => statistic.minimum_samples,
            "maximum_exceedance_probability" =>
                statistic.maximum_exceedance_probabilities,
        ],
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "maximum_vs_switch_time.svg"),
        close_time_s,
        ["maximum_bus3_v_pu" => statistic.maximum_samples];
        title = "Switching Ensemble Response",
        x_label = "breaker closing time (s)",
        y_label = "maximum BUS3 voltage (pu)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Reproducible Switching Ensemble",
        (
            energizations = ensemble.energization_count,
            seed = ensemble.seed,
            replay_signature = ensemble.deterministic_replay_signature,
            preferred_distribution = statistic.preferred_distribution,
            physical_checks_passed = ensemble.physical_checks_passed,
            julia_only = true,
        ),
    )
    @printf("Schedules: %s\n", schedule_path)
    @printf("Extrema: %s\n", extrema_path)
    @printf("Plot: %s\n", svg_path)
    @printf("Summary: %s\n", summary_path)
end

main()
