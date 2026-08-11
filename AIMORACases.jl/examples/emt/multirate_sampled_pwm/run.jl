#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.EMTStudy
using .ExampleSupport

const TICK_S = 1.0e-6
const END_TICK = 200
const PLANT_TIME_CONSTANT_S = 40.0e-6

mutable struct MultirateSampledPWMState
    reference::Float64
    plant_state::Float64
    held_duty::Float64
    gate_high::Bool
    electrical_step_count::Int
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    owner = MultirateSampledPWMState(0.65, 0.0, 0.5, false, 0)

    controller = EMTExactSampledControlTask(
        :sampled_controller,
        20.0e-6,
        (state, _time_s, _sample_index) -> state.plant_state,
        (state, measurement, _time_s, _sample_index) ->
            clamp(0.55 + 0.8 * (state.reference - measurement), 0.05, 0.95),
        (state, duty, _time_s, _sample_index) -> (state.held_duty = duty);
        tick_s = TICK_S,
        computational_delay_s = 3.0e-6,
        initial_output = owner.held_duty,
        priority = -10,
    )
    pwm = EMTExactPWMTask(
        :trailing_edge_pwm,
        10.0e-6,
        (state, _time_s, _cycle_index) -> state.held_duty,
        (state, high, _time_s, _edge_index) -> (state.gate_high = high);
        tick_s = TICK_S,
        priority = 0,
        power_history_invalidating = false,
    )
    electrical = EMTExactSampledTask(
        :electrical_plant,
        TICK_S,
        (state, _time_s, _execution_index) -> begin
            target = state.gate_high ? 1.0 : 0.0
            state.plant_state +=
                TICK_S * (target - state.plant_state) / PLANT_TIME_CONSTANT_S
            state.electrical_step_count += 1
        end;
        tick_s = TICK_S,
        priority = 10,
    )
    scheduler = EMTExactSampledTaskScheduler(
        TICK_S;
        tasks = [electrical, pwm, controller],
    )

    ticks = collect(0:END_TICK)
    times_s = Float64.(ticks) .* TICK_S
    plant_state = Vector{Float64}(undef, length(ticks))
    duty = similar(plant_state)
    gate = similar(plant_state)
    for (index, tick) in pairs(ticks)
        run_due_emt_sampled_tasks!(scheduler, owner, tick * TICK_S)
        plant_state[index] = owner.plant_state
        duty[index] = owner.held_duty
        gate[index] = owner.gate_high ? 1.0 : 0.0
    end

    expected_write_ticks = [
        sample.sample_tick + controller.computational_delay_ticks
        for sample in controller.samples
        if sample.release_tick <= END_TICK
    ]
    write_ticks = getfield.(controller.writes, :write_tick)
    edge_ticks = getfield.(pwm.occurrences, :tick)
    occurrence_ticks_exact = all(
        occurrence.time_s == occurrence.tick * TICK_S
        for occurrence in scheduler.occurrences
    )
    delay_exact = write_ticks == expected_write_ticks
    edge_ticks_unique = length(unique(edge_ticks)) == length(edge_ticks)
    physical_bounds = all(isfinite, plant_state) &&
        all(value -> 0.0 <= value <= 1.0, plant_state) &&
        all(value -> 0.0 <= value <= 1.0, duty)
    occurrence_ticks_exact && delay_exact && edge_ticks_unique && physical_bounds ||
        error("multirate sampled/PWM acceptance checks failed")

    csv_path = write_series_csv(
        joinpath(output_dir, "multirate_sampled_pwm.csv"),
        "time_s",
        times_s,
        [
            "tick" => ticks,
            "plant_state" => plant_state,
            "held_duty" => duty,
            "gate_high" => gate,
        ],
    )
    svg_path = write_waveform_svg(
        joinpath(output_dir, "multirate_sampled_pwm.svg"),
        times_s,
        [
            "plant_state" => plant_state,
            "held_duty" => duty,
            "gate_high" => gate,
        ];
        title = "Exact Multirate Sampled Control and PWM",
        y_label = "normalized value",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Exact Multirate Sampled Control and PWM",
        (
            scheduler_tick_s = TICK_S,
            electrical_period_ticks = electrical.period_ticks,
            controller_period_ticks = controller.period_ticks,
            computational_delay_ticks = controller.computational_delay_ticks,
            pwm_carrier_period_ticks = pwm.carrier_period_ticks,
            electrical_step_count = owner.electrical_step_count,
            controller_sample_count = controller.sample_count,
            controller_write_count = controller.write_count,
            pwm_cycle_count = pwm.cycle_count,
            pwm_edge_count = pwm.edge_count,
            occurrence_ticks_exact = occurrence_ticks_exact,
            computational_delay_exact = delay_exact,
            pwm_edge_ticks_unique = edge_ticks_unique,
            physical_bounds_passed = physical_bounds,
            final_plant_state = owner.plant_state,
            final_held_duty = owner.held_duty,
            julia_only = true,
        ),
    )
    println("CSV: ", csv_path)
    println("Waveform: ", svg_path)
    println("Summary: ", summary_path)
end

main()
