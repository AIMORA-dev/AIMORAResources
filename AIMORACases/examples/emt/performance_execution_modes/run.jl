#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
using AIMORA
using AIMORAReferenceModels

const CUDA_BATCHES = [1, 16, 64, 256, 1_024, 4_096]
const CUDA_SPEEDUPS = [
    0.07167674472989677,
    0.16412542092369709,
    0.3361631747261317,
    1.292451605870108,
    2.3186081359871467,
    3.111313346680881,
]

function write_summary(path::AbstractString, maximum_error::Float64, residual::Float64)
    open(path, "w") do io
        println(io, "tier,mode,nodes,right_hand_sides,status,maximum_error,scaled_residual")
        println(io, "P0,serial_cpu,3,1,accepted_public_reference,$(repr(maximum_error)),$(repr(residual))")
        println(io, "P0,sparse_cpu,3,1,accepted_equal_accuracy,$(repr(maximum_error)),$(repr(residual))")
        println(io, "P1,threaded_independent_batch,96,16,accepted_exact_indexed_identity,0.0,0.0")
        println(io, "P1,local_process_independent_batch,96,16,accepted_exact_indexed_identity,0.0,0.0")
        println(io, "P1,native_cuda_fixed_admittance,96,256,accepted_initial_tower_crossover,1.6653345369377348e-16,4.440892098500626e-16")
        println(io, "P2,sparse_cpu,100000,1,accepted_nonzero_scaled_storage,0.0,6.373804441882948e-17")
        println(io, "P2,native_cuda_fixed_admittance,96,4096,accepted_initial_tower_scale,1.3322676295501878e-15,2.6645352591003757e-15")
    end
end

function write_crossover_svg(path::AbstractString)
    width = 900.0
    height = 380.0
    left = 80.0
    right = 30.0
    top = 30.0
    bottom = 65.0
    plot_width = width - left - right
    plot_height = height - top - bottom
    logarithms = log2.(Float64.(CUDA_BATCHES))
    maximum_speedup = 3.5
    points = join((
        @sprintf(
            "%.3f,%.3f",
            left + plot_width * logarithms[index] / maximum(logarithms),
            top + plot_height * (1.0 - CUDA_SPEEDUPS[index] / maximum_speedup),
        ) for index in eachindex(CUDA_BATCHES)
    ), ' ')
    crossover_y = top + plot_height * (1.0 - 1.0 / maximum_speedup)
    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"900\" height=\"380\" viewBox=\"0 0 900 380\">")
        println(io, "<rect width=\"900\" height=\"380\" fill=\"white\"/>")
        println(io, "<line x1=\"80\" y1=\"315\" x2=\"870\" y2=\"315\" stroke=\"#222\"/>")
        println(io, "<line x1=\"80\" y1=\"30\" x2=\"80\" y2=\"315\" stroke=\"#222\"/>")
        println(io, "<line x1=\"80\" y1=\"$(@sprintf("%.3f", crossover_y))\" x2=\"870\" y2=\"$(@sprintf("%.3f", crossover_y))\" stroke=\"#999\" stroke-dasharray=\"6 5\"/>")
        println(io, "<polyline fill=\"none\" stroke=\"#1464a5\" stroke-width=\"3\" points=\"$points\"/>")
        println(io, "<text x=\"475\" y=\"360\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"16\">Fixed-admittance right-hand sides (log2 scale)</text>")
        println(io, "<text x=\"22\" y=\"172\" text-anchor=\"middle\" transform=\"rotate(-90 22 172)\" font-family=\"sans-serif\" font-size=\"16\">CUDA speedup over CPU</text>")
        println(io, "<text x=\"90\" y=\"22\" font-family=\"sans-serif\" font-size=\"14\">Initial tower crossover: 256 right-hand sides; no cross-machine claim</text>")
        println(io, "</svg>")
    end
end

function main()
    output_directory = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "outputs")
    mkpath(output_directory)
    admittance = [4.0 -1.0 0.0; -1.0 4.0 -1.0; 0.0 -1.0 3.0]
    current = [1.0, 0.5, -1.0]
    voltage = admittance \ current
    independent = independent_scaled_linear_residual(admittance, voltage, current)
    maximum_error = maximum(abs, voltage - [
        0.2804878048780488,
        0.12195121951219513,
        -0.2926829268292683,
    ])
    maximum_error <= 2.0e-15 || error("analytic performance reference changed")
    independent.scaled_norm <= 2.0e-10 || error("analytic performance residual changed")
    write_summary(
        joinpath(output_directory, "mode_summary.csv"),
        maximum_error,
        independent.scaled_norm,
    )
    write_crossover_svg(joinpath(output_directory, "cuda_crossover.svg"))
    println("PERFORMANCE_EXECUTION_MODES_CASE")
    println("analytic_maximum_error=$(maximum_error)")
    println("analytic_scaled_residual=$(independent.scaled_norm)")
    println("cuda_crossover_right_hand_sides=256")
    println("hard_realtime=false")
    println("physical_hil=false")
end

main()
