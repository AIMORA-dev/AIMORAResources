include(normpath(joinpath(@__DIR__, "..", "..", "support", "ModernMachineExample.jl")))

output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
result = run_machine_product(output_dir, :emt_machine_synchronous_condenser)
println("Synchronous-condenser product: steps=", result.trace.result.diagnostics.accepted_step_count,
    " restart_exact=", result.restart_exact)
