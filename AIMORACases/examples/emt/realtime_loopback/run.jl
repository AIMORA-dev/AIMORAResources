#!/usr/bin/env julia

using Printf
using SHA

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
using AIMORA.RealtimeLoop
using AIMORAReferenceModels

mutable struct LoopbackModelState
    value::Float64
    accepted_index::Int
    input_trace::Vector{Float64}
    output_trace::Vector{Float64}
end

mutable struct LoopbackModelCheckpoint
    value::Float64
    accepted_index::Int
end

function compile_controller(output_directory::AbstractString)
    Sys.islinux() || error("the initial real-code loopback example requires native Linux")
    compiler = something(Sys.which(get(ENV, "CC", "gcc")), nothing)
    compiler === nothing && error("a C compiler is required for the real-code loopback")
    source = joinpath(@__DIR__, "controller", "aimora_realtime_controller.c")
    library = joinpath(output_directory, "aimora_realtime_controller.so")
    run(`$compiler -std=c11 -O2 -fPIC -shared -o $library $source`)
    compiler_identity = replace(
        first(readlines(`$compiler --version`)),
        ',' => ';',
    )
    return library, bytes2hex(sha256(read(library))), compiler_identity
end

function write_timing_csv(path::AbstractString, samples)
    open(path, "w") do io
        println(io, "step,release_ns,start_ns,completion_ns,jitter_ns,computation_ns,response_ns,slack_ns,overrun")
        for sample in samples
            println(io, join((
                sample.step,
                sample.release_ns,
                sample.start_ns,
                sample.completion_ns,
                sample.jitter_ns,
                sample.computation_ns,
                sample.response_ns,
                sample.slack_ns,
                sample.overrun,
            ), ','))
        end
    end
end

function json_string(value)
    escaped = replace(
        string(value),
        '\\' => "\\\\",
        '"' => "\\\"",
        '\n' => "\\n",
        '\r' => "\\r",
        '\t' => "\\t",
    )
    return "\"$(escaped)\""
end

function write_summary_json(
    path::AbstractString,
    result,
    maximum_error::Float64,
    library_hash::AbstractString,
    compiler::AbstractString,
    profile,
)
    summary = result.timing_summary
    open(path, "w") do io
        println(io, "{")
        println(io, "  \"schema\": \"aimora-realtime-loopback-v1\",")
        println(io, "  \"accepted_steps\": $(result.accepted_steps),")
        println(io, "  \"overruns\": $(summary.overruns),")
        println(io, "  \"maximum_response_ns\": $(summary.maximum_response_ns),")
        println(io, "  \"maximum_jitter_ns\": $(summary.maximum_jitter_ns),")
        println(io, "  \"maximum_independent_error\": $(repr(maximum_error)),")
        println(io, "  \"controller_sha256\": $(json_string(library_hash)),")
        println(io, "  \"controller_compiler\": $(json_string(compiler)),")
        println(io, "  \"profile\": $(json_string(profile)),")
        println(io, "  \"physical_hil\": false,")
        println(io, "  \"hard_realtime\": false")
        println(io, "}")
    end
end

function write_response_svg(path::AbstractString, samples)
    responses = Float64[getfield(sample, :response_ns) / 1.0e6 for sample in samples]
    width = 900.0
    height = 360.0
    left = 70.0
    right = 30.0
    top = 30.0
    bottom = 55.0
    plot_width = width - left - right
    plot_height = height - top - bottom
    maximum_response = max(maximum(responses), 1.0e-9)
    points = join((
        @sprintf(
            "%.3f,%.3f",
            left + plot_width * (index - 1) / max(length(responses) - 1, 1),
            top + plot_height * (1.0 - response / maximum_response),
        ) for (index, response) in enumerate(responses)
    ), ' ')
    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"900\" height=\"360\" viewBox=\"0 0 900 360\">")
        println(io, "<rect width=\"900\" height=\"360\" fill=\"white\"/>")
        println(io, "<line x1=\"70\" y1=\"305\" x2=\"870\" y2=\"305\" stroke=\"#222\"/>")
        println(io, "<line x1=\"70\" y1=\"30\" x2=\"70\" y2=\"305\" stroke=\"#222\"/>")
        println(io, "<polyline fill=\"none\" stroke=\"#1464a5\" stroke-width=\"2\" points=\"$points\"/>")
        println(io, "<text x=\"450\" y=\"345\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"16\">Logical step</text>")
        println(io, "<text x=\"18\" y=\"168\" text-anchor=\"middle\" transform=\"rotate(-90 18 168)\" font-family=\"sans-serif\" font-size=\"16\">Response time (ms)</text>")
        println(io, "<text x=\"70\" y=\"22\" font-family=\"sans-serif\" font-size=\"14\">maximum = $(@sprintf("%.6f", maximum_response)) ms</text>")
        println(io, "</svg>")
    end
end

function main()
    output_directory = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "outputs")
    mkpath(output_directory)
    channels = [
        RealtimeChannel(:controller_command, :input, "1", 1.0, 0.0, -10.0, 10.0, 0.0),
        RealtimeChannel(:model_measurement, :output, "1", 1.0, 0.0, -10.0, 10.0, 0.0),
    ]
    controller_build_directory = mktempdir()
    library_path, library_hash, compiler = compile_controller(controller_build_directory)
    interface = open_shared_library_controller(library_path, library_hash, channels)
    target = RealtimeTarget(
        :aimora_c_controller_loopback,
        SharedLibraryControllerTarget;
        period_ns=10_000_000,
        step_count=100,
        overrun_policy=MeasureOnlyOverrun,
    )
    preparation = prepare_realtime_target(target, channels, interface)
    preparation isa RealtimePreparation || error(preparation.message)
    state = LoopbackModelState(0.0, 0, zeros(target.step_count), zeros(target.step_count))
    checkpoint = LoopbackModelCheckpoint(0.0, 0)
    capture_state! = function (destination, source)
        destination.value = source.value
        destination.accepted_index = source.accepted_index
        return destination
    end
    restore_state! = function (destination, source)
        destination.value = source.value
        destination.accepted_index = source.accepted_index
        return destination
    end
    model_step! = function (
        runtime,
        inputs,
        outputs,
        logical_step,
        _logical_time_s,
        step_s,
    )
        runtime.value += step_s * inputs[1]
        outputs[1] = runtime.value
        runtime.accepted_index = logical_step + 1
        runtime.input_trace[runtime.accepted_index] = inputs[1]
        runtime.output_trace[runtime.accepted_index] = outputs[1]
        return nothing
    end
    result = run_paced_realtime!(
        model_step!,
        state,
        interface,
        preparation;
        checkpoint,
        capture_state!,
        restore_state!,
        input_values=[1.0],
        output_values=[0.0],
    )
    result.failure === nothing || error(result.failure.message)
    reference_state = 0.0
    reference_controller_state = 0.0
    reference_input = 1.0
    maximum_error = 0.0
    for index in 1:target.step_count
        reference_state += reference_input * target.period_ns / 1.0e9
        maximum_error = max(maximum_error, abs(reference_state - state.output_trace[index]))
        controller = independent_loopback_controller_step(
            reference_controller_state,
            reference_state,
            0.25,
            2.0,
        )
        reference_controller_state = controller.state
        reference_input = controller.output
    end
    maximum_error <= 1.0e-12 || error(
        "C real-code loopback differs from the independent reference: $maximum_error",
    )
    write_timing_csv(joinpath(output_directory, "timing.csv"), result.timing_samples)
    write_response_svg(joinpath(output_directory, "response_time.svg"), result.timing_samples)
    write_summary_json(
        joinpath(output_directory, "summary.json"),
        result,
        maximum_error,
        library_hash,
        compiler,
        preparation.profile,
    )
    open(joinpath(output_directory, "summary.csv"), "w") do io
        println(io, "metric,value,unit")
        println(io, "accepted_steps,$(result.accepted_steps),count")
        println(io, "overruns,$(result.timing_summary.overruns),count")
        println(io, "maximum_response_ns,$(result.timing_summary.maximum_response_ns),ns")
        println(io, "maximum_jitter_ns,$(result.timing_summary.maximum_jitter_ns),ns")
        println(io, "maximum_independent_error,$(repr(maximum_error)),1")
        println(io, "controller_sha256,$library_hash,sha256")
        println(io, "controller_compiler,$compiler,identity")
        println(io, "profile,$(preparation.profile),label")
        println(io, "physical_hil,false,boolean")
        println(io, "hard_realtime,false,boolean")
    end
    close_realtime_interface!(interface)
    println("REALTIME_LOOPBACK_CASE")
    println("accepted_steps=$(result.accepted_steps)")
    println("overruns=$(result.timing_summary.overruns)")
    println("maximum_independent_error=$(repr(maximum_error))")
    println("profile=$(preparation.profile)")
    println("physical_hil=false")
end

main()
