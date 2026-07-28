using BPAEMTPReference

deck_path = joinpath(@__DIR__, "rlc_energization.deck")
output_dir = isempty(ARGS) ? joinpath(@__DIR__, "outputs") : abspath(only(ARGS))
result = BPAEMTPReference.run_deck(
    deck_path,
    Val(:file);
    output_dir = output_dir,
    build_if_missing = true,
    timeout_s = 30.0,
)

println("Status: ", result.status)
println("Process OK: ", result.process_ok)
println("Report: ", abspath(result.report_path))
println(result.report_excerpt)
