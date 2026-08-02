#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA.EMTStudy
using AIMORA.Figures
using .ExampleSupport

const SCENARIOS = (
    (
        name = :baseline,
        load_conductance_pu = 0.843,
        inverter_q_pu = 0.05,
    ),
    (
        name = :light_load,
        load_conductance_pu = 0.50,
        inverter_q_pu = 0.05,
    ),
    (
        name = :heavy_load,
        load_conductance_pu = 1.50,
        inverter_q_pu = 0.05,
    ),
    (
        name = :reactive_power_command,
        load_conductance_pu = 0.843,
        inverter_q_pu = 0.25,
    ),
)

function configuration(scenario)
    return UnifiedEMTConfig(
        t_end_s = 0.150,
        dt_s = 20e-6,
        initial_bus_pu = 0.972,
        load_conductance_pu = scenario.load_conductance_pu,
        inverter_p0_pu = 0.35,
        inverter_p1_pu = 0.80,
        inverter_q_pu = scenario.inverter_q_pu,
    )
end

function main()
    output_dir = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "outputs")
    mkpath(output_dir)

    runs = [
        (
            scenario = scenario,
            cfg = configuration(scenario),
            rows = run_reduced_feeder_inverter(configuration(scenario)),
        )
        for scenario in SCENARIOS
    ]
    baseline = first(runs)
    cfg = baseline.cfg
    rows = baseline.rows

    write_unified_csv(joinpath(output_dir, "reduced_feeder_timeseries.csv"), rows)
    write_unified_summary(joinpath(output_dir, "summary.json"), rows, cfg)
    write_unified_voltage_svg(joinpath(output_dir, "reduced_feeder_voltage.svg"), rows)
    write_unified_power_svg(joinpath(output_dir, "reduced_feeder_inverter_power.svg"), rows)

    metrics_path = joinpath(output_dir, "operating_point_metrics.csv")
    open(metrics_path, "w") do io
        println(
            io,
            "scenario,load_conductance_pu,q_command_pu,final_bus_voltage_pu,final_active_power_pu,final_reactive_power_pu",
        )
        for run in runs
            final = last(run.rows)
            @printf(
                io,
                "%s,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                String(run.scenario.name),
                run.cfg.load_conductance_pu,
                run.cfg.inverter_q_pu,
                final[2],
                final[6],
                final[7],
            )
        end
    end
    voltage_plot = write_waveform_svg(
        joinpath(output_dir, "operating_point_voltage.svg"),
        [row[1] for row in rows],
        [
            "$(run.scenario.name)_bus_voltage_pu" => [row[2] for row in run.rows]
            for run in runs
        ];
        title = "Reduced-Feeder Operating-Point Sensitivity",
        y_label = "bus voltage (pu)",
    )
    light_load_final = last(runs[2].rows)[2]
    heavy_load_final = last(runs[3].rows)[2]
    baseline_final = last(runs[1].rows)[2]
    reactive_final = last(runs[4].rows)[2]
    light_load_final > heavy_load_final ||
        error("lighter load did not produce the expected higher bus voltage")
    isapprox(baseline_final, reactive_final; atol = 1.0e-12, rtol = 0.0) ||
        error("reactive command unexpectedly changed this scalar active-current network")
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Reduced-Feeder Inverter Sensitivity",
        (
            julia_only = true,
            scenario_count = length(runs),
            timestep_s = cfg.dt_s,
            duration_s = cfg.t_end_s,
            light_load_voltage_exceeds_heavy_load = true,
            reactive_power_affects_network_voltage = false,
            interpretation =
                "Load conductance changes the solved bus voltage; reactive power is reported but intentionally does not enter this reduced scalar current injection.",
        ),
    )

    final_row = rows[end]
    @printf("Output: %s\n", abspath(output_dir))
    @printf("Engine: Julia unified EMT timestep loop\n")
    @printf("Legacy Fortran in loop: no\n")
    @printf("Samples: %d, dt: %.1f us\n", length(rows), cfg.dt_s * 1e6)
    @printf("Final bus voltage: %.4f pu\n", final_row[2])
    @printf("Final inverter P/Q: %.4f / %.4f pu\n", final_row[6], final_row[7])
    @printf("Scenario metrics: %s\n", abspath(metrics_path))
    @printf("Scenario plot: %s\n", voltage_plot)
    @printf("Scenario summary: %s\n", summary_path)
end

main()
