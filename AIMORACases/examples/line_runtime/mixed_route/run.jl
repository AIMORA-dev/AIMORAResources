include(normpath(joinpath(@__DIR__, "..", "..", "support", "CoupledLineRuntimeExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    result = run_coupled_line_runtime_example(
        output_dir;
        case_id=:coupled_line_runtime_mixed_route,
        fit_paths=[
            coupled_line_runtime_fit_path(
                "mixed_route",
                "outputs",
                "overhead_segment_fit.toml",
            ),
            coupled_line_runtime_fit_path(
                "mixed_route",
                "outputs",
                "cable_segment_fit.toml",
            ),
        ],
        alternative_fit_path_sets=[[
            joinpath(
                @__DIR__,
                "inputs",
                "overhead_segment_soil_110_ohm_m_fit.toml",
            ),
            joinpath(
                @__DIR__,
                "inputs",
                "cable_segment_soil_110_ohm_m_fit.toml",
            ),
        ]],
        from_node_orders=[[1, 2, 3], [6, 4, 5]],
        to_node_orders=[[4, 5, 6], [7, 8, 9]],
        source_nodes=[1, 2, 3],
        receiving_nodes=[8, 9, 7],
        fault_node=8,
    )
    println("Mixed-route coupled runtime: segments=2 steps=",
        length(result.times_s) - 1, " restart_exact=", result.restart_exact)
end

main()
