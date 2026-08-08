module BPAEMTPReference

export ReferenceRunResult,
       build_reference,
       executable_path,
       read_report,
       report_excerpt,
       report_status,
       run_deck,
       source_dir

Base.@kwdef struct ReferenceRunResult
    executable::String
    report_path::String
    exit_code::Int
    process_ok::Bool
    status::Symbol
    error_detected::Bool
    report_excerpt::String
end

package_root() = normpath(joinpath(@__DIR__, ".."))
source_dir() = joinpath(package_root(), "src", "fortran")
executable_path() = joinpath(package_root(), "build", "emtp")

function build_reference()
    script = joinpath(package_root(), "scripts", "build_fortran.sh")
    isfile(script) || error("Missing registered reference build entrypoint: $script")
    run(addenv(`bash $script`, "EMTP_DEBUG_BUILD" => "1"))
    executable = executable_path()
    isfile(executable) || error("Reference build completed without producing $executable")
    return executable
end

function report_excerpt(report_text::AbstractString; max_lines::Int = 8)
    lines = String[]
    for raw in split(replace(report_text, '\0' => ' '), '\n')
        line = strip(raw)
        isempty(line) && continue
        push!(lines, line)
        length(lines) >= max_lines && break
    end
    return join(lines, "\n")
end

function report_status(report_text::AbstractString, exit_code::Integer)
    text = String(report_text)
    if occursin("Fortran runtime error", text)
        return :runtime_error
    elseif occursin("ERROR/ERROR", text) ||
           occursin("DATA CRISIS", text) ||
           occursin("THE EMTP LOGIC HAS DETECTED AN ERROR CONDITION", text) ||
           occursin("KILL CODE NUMBER", text)
        return :deck_data_error
    elseif exit_code != 0
        return :process_failed
    elseif occursin("TEMPORARY ERROR STOP IN \"STOPTP\"", text) &&
           occursin("NCHAIN, LASTOV =   -1", text)
        return :clean_stop
    elseif occursin("EMTP BEGINS", text)
        return :completed
    else
        return :unknown
    end
end

read_report(result::ReferenceRunResult) = read(result.report_path, String)

function run_deck(
    deck_text::AbstractString;
    output_dir::AbstractString = mktempdir(),
    report_name::AbstractString = "fortran_report.out",
    build_if_missing::Bool = false,
    timeout_s::Real = 120.0,
)
    executable = executable_path()
    if !isfile(executable)
        build_if_missing ||
            error("Missing compiled reference executable. Run BPAEMTPReference.build_reference().")
        executable = build_reference()
    end

    mkpath(output_dir)
    state_dir = joinpath(output_dir, "state")
    mkpath(state_dir)
    report_path = joinpath(output_dir, report_name)
    timeout_s > 0 || throw(ArgumentError("timeout_s must be positive"))
    timed_out = false
    process = mktemp(output_dir) do _, deck
        write(deck, String(deck_text))
        flush(deck)
        seekstart(deck)
        open(report_path, "w") do report
            command = addenv(
                Cmd(`$executable`; dir = output_dir),
                "EMTP_GOLDEN_TAPE_DIR" => state_dir,
            )
            child = run(
                pipeline(
                    command,
                    stdin = deck,
                    stdout = report,
                    stderr = report,
                );
                wait = false,
            )
            wait_status = timedwait(
                () -> process_exited(child),
                Float64(timeout_s);
                pollint = 0.05,
            )
            if wait_status == :timed_out
                timed_out = true
                kill(child)
            end
            wait(child)
            child
        end
    end
    exit_code = process.exitcode
    text = read(report_path, String)
    status = timed_out ? :timed_out : report_status(text, exit_code)
    return ReferenceRunResult(
        executable = executable,
        report_path = report_path,
        exit_code = exit_code,
        process_ok = success(process),
        status = status,
        error_detected =
            status in (
                :runtime_error,
                :deck_data_error,
                :process_failed,
                :timed_out,
                :unknown,
            ),
        report_excerpt = report_excerpt(text),
    )
end

function run_deck(
    deck_path::AbstractString,
    ::Val{:file};
    kwargs...,
)
    isfile(deck_path) || throw(ArgumentError("Deck file does not exist: $deck_path"))
    return run_deck(read(deck_path, String); kwargs...)
end

end
