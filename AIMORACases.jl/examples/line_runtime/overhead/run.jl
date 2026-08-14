include(normpath(joinpath(@__DIR__, "..", "..", "support", "CoupledLineRuntimeExample.jl")))

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    result = run_coupled_line_runtime_example(
        output_dir;
        case_id=:coupled_line_runtime_overhead,
        fit_paths=[coupled_line_runtime_fit_path(
            "overhead",
            "outputs",
            "coupled_line_fit.toml",
        )],
        alternative_fit_path_sets=[[
            joinpath(@__DIR__, "inputs", "soil_110_ohm_m_fit.toml"),
        ]],
        from_node_orders=[[1, 2, 3]],
        to_node_orders=[[4, 5, 6]],
        source_nodes=[1, 2, 3],
        receiving_nodes=[4, 5, 6],
        fault_node=4,
    )
    println("Overhead coupled runtime: steps=", length(result.times_s) - 1,
        " restart_exact=", result.restart_exact)
end

main()
