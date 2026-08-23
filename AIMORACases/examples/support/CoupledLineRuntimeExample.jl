#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "WidebandLineParameterExample.jl")))

using AIMORA.CoupledLineFitting
using AIMORA.CoupledLineRuntime
using AIMORA.Lines
using AIMORA.Branches
using AIMORA.Switches
using AIMORA.Nodal

const COUPLED_LINE_RUNTIME_EXAMPLE_ROOT = normpath(joinpath(@__DIR__, ".."))
const COUPLED_LINE_RUNTIME_TIMESTEP_S = 10.0e-6
const COUPLED_LINE_RUNTIME_FREQUENCY_HZ = 60.0
const COUPLED_LINE_RUNTIME_END_TIME_S = 2.0e-3
const COUPLED_LINE_RUNTIME_FAULT_START_S = 0.75e-3
const COUPLED_LINE_RUNTIME_FAULT_END_S = 1.25e-3
const COUPLED_LINE_RUNTIME_SOURCE_PEAK_V = 100_000.0
const COUPLED_LINE_RUNTIME_SOURCE_CONDUCTANCE_S = 10_000.0
const COUPLED_LINE_RUNTIME_LOAD_CONDUCTANCE_S = 0.02

function coupled_line_runtime_fit_path(parts...)
    return normpath(joinpath(
        COUPLED_LINE_RUNTIME_EXAMPLE_ROOT,
        "line_fitting",
        parts...,
    ))
end

function _runtime_source_phasors(source_nodes)
    phase_angles_rad = (0.0, -2.0 * pi / 3.0, 2.0 * pi / 3.0)
    length(source_nodes) == 3 || throw(ArgumentError(
        "public coupled-line runtime source must contain three phases",
    ))
    return Dict(
        source_nodes[index] =>
            COUPLED_LINE_RUNTIME_SOURCE_PEAK_V * cis(phase_angles_rad[index])
        for index in eachindex(source_nodes)
    )
end

function _runtime_source_elements(source_nodes)
    phase_angles_rad = (0.0, -2.0 * pi / 3.0, 2.0 * pi / 3.0)
    return Any[
        TheveninSource(
            source_nodes[index],
            COUPLED_LINE_RUNTIME_SOURCE_CONDUCTANCE_S,
            let angle_rad = phase_angles_rad[index]
                time_s -> COUPLED_LINE_RUNTIME_SOURCE_PEAK_V * cos(
                    2.0 * pi * COUPLED_LINE_RUNTIME_FREQUENCY_HZ * time_s +
                    angle_rad,
                )
            end,
        ) for index in eachindex(source_nodes)
    ]
end

function _prepare_runtime_lines(
    fit_paths,
    from_node_orders,
    to_node_orders,
    timestep_s,
)
    length(fit_paths) == length(from_node_orders) == length(to_node_orders) ||
        throw(DimensionMismatch(
            "public coupled-line runtime segment paths and node maps must align",
        ))
    settings = CoupledLineRuntimeSettings(;
        timestep_s,
    )
    fits = [read_coupled_line_fit(path) for path in fit_paths]
    preparations = [prepare_coupled_line_runtime(fit, settings) for fit in fits]
    lines = [
        coupled_frequency_dependent_line(
            preparations[index],
            from_node_orders[index],
            to_node_orders[index],
        ) for index in eachindex(preparations)
    ]
    return (; settings, fits, preparations, lines)
end

function _initialize_runtime_lines!(
    lines,
    preparations,
    source_nodes,
    receiving_nodes,
)
    node_count = maximum(vcat(
        collect(keys(_runtime_source_phasors(source_nodes))),
        receiving_nodes,
        reduce(vcat, (line.port_nodes for line in lines)),
    ))
    admittance = zeros(ComplexF64, node_count, node_count)
    right_hand_side = zeros(ComplexF64, node_count)
    for (node, voltage_phasor) in _runtime_source_phasors(source_nodes)
        admittance[node, node] += COUPLED_LINE_RUNTIME_SOURCE_CONDUCTANCE_S
        right_hand_side[node] +=
            COUPLED_LINE_RUNTIME_SOURCE_CONDUCTANCE_S * voltage_phasor
    end
    for node in receiving_nodes
        admittance[node, node] += COUPLED_LINE_RUNTIME_LOAD_CONDUCTANCE_S
    end
    for (line, preparation) in zip(lines, preparations)
        terminal_admittance = coupled_line_runtime_terminal_admittance(
            preparation,
            COUPLED_LINE_RUNTIME_FREQUENCY_HZ,
        )
        for column in eachindex(line.port_nodes), row in eachindex(line.port_nodes)
            row_node = line.port_nodes[row]
            column_node = line.port_nodes[column]
            row_node == 0 || column_node == 0 ||
                (admittance[row_node, column_node] += terminal_admittance[row, column])
        end
    end
    isfinite(cond(admittance)) || error(
        "public coupled-line runtime initialization network is singular",
    )
    voltage_phasor = admittance \ right_hand_side
    for line in lines
        phase_count = length(line.from_nodes)
        from_voltage = voltage_phasor[line.from_nodes]
        to_voltage = voltage_phasor[line.to_nodes]
        initialize_coupled_frequency_dependent_line_sinusoidal!(
            line,
            from_voltage,
            to_voltage,
            COUPLED_LINE_RUNTIME_FREQUENCY_HZ,
        )
        length(from_voltage) == phase_count || error(
            "public coupled-line runtime initialization phase count changed",
        )
    end
    return voltage_phasor
end

function _runtime_network(
    fit_paths,
    from_node_orders,
    to_node_orders,
    source_nodes,
    receiving_nodes,
    fault_node,
    timestep_s,
)
    prepared = _prepare_runtime_lines(
        fit_paths,
        from_node_orders,
        to_node_orders,
        timestep_s,
    )
    elements = _runtime_source_elements(source_nodes)
    append!(elements, prepared.lines)
    append!(elements, (
        ConductanceBranch(node, 0, COUPLED_LINE_RUNTIME_LOAD_CONDUCTANCE_S)
        for node in receiving_nodes
    ))
    fault_switch = TimeSwitch(
        fault_node,
        0;
        close_time_s=COUPLED_LINE_RUNTIME_FAULT_START_S,
        open_time_s=COUPLED_LINE_RUNTIME_FAULT_END_S,
        initially_closed=false,
        on_conductance=100.0,
        off_conductance=0.0,
    )
    push!(elements, fault_switch)
    node_count = maximum(vcat(
        source_nodes,
        receiving_nodes,
        reduce(vcat, (line.port_nodes for line in prepared.lines)),
    ))
    system = NodalSystem(node_count, elements)
    initial_voltage_phasor = _initialize_runtime_lines!(
        prepared.lines,
        prepared.preparations,
        source_nodes,
        receiving_nodes,
    )
    system.v .= real.(initial_voltage_phasor)
    return merge(prepared, (; system, fault_switch, initial_voltage_phasor))
end

function _runtime_trace_row(lines, voltage, receiving_nodes, fault_switch, time_s)
    first_line = first(lines).runtime_state
    last_line = last(lines).runtime_state
    phase_count = length(first(lines).from_nodes)
    return (
        receiving_voltage_v=Float64.(voltage[receiving_nodes]),
        sending_current_a=copy(first_line.terminal_current_a[1:phase_count]),
        receiving_current_a=copy(last_line.terminal_current_a[(phase_count + 1):end]),
        terminal_power_w=sum(line.runtime_state.terminal_power_w for line in lines),
        cumulative_supplied_energy_j=sum(
            line.runtime_state.cumulative_supplied_energy_j for line in lines
        ),
        maximum_kcl_residual_a=maximum(
            line.runtime_state.maximum_kcl_residual_a for line in lines
        ),
        fault_closed=switch_closed(fault_switch, time_s) ? 1.0 : 0.0,
    )
end

function _runtime_envelope_series(trace, alternative_traces)
    all_traces = [trace, alternative_traces...]
    all(candidate -> candidate.times_s == trace.times_s, all_traces) ||
        error("coupled-line runtime uncertainty trajectories use different time grids")
    row_count = length(trace.rows)
    all(candidate -> length(candidate.rows) == row_count, all_traces) ||
        error("coupled-line runtime uncertainty trajectories use different row counts")
    all(
        candidate -> all(
            candidate.rows[index].fault_closed == trace.rows[index].fault_closed
            for index in 1:row_count
        ),
        all_traces,
    ) || error("coupled-line runtime uncertainty trajectories changed event timing")
    phase_count = length(first(trace.rows).receiving_voltage_v)
    series = Pair{String,Vector{Float64}}[]
    for phase in 1:phase_count
        for (quantity, label, unit) in (
            (:receiving_voltage_v, "receiving_voltage", "v"),
            (:sending_current_a, "sending_current", "a"),
            (:receiving_current_a, "receiving_current", "a"),
        )
            values = [
                Float64[getfield(candidate.rows[index], quantity)[phase]
                    for candidate in all_traces]
                for index in 1:row_count
            ]
            push!(series,
                "$(label)_phase_$(phase)_minimum_$(unit)" => minimum.(values))
            push!(series,
                "$(label)_phase_$(phase)_maximum_$(unit)" => maximum.(values))
        end
    end
    for (quantity, label, unit) in (
        (:terminal_power_w, "terminal_power", "w"),
        (:cumulative_supplied_energy_j, "cumulative_supplied_energy", "j"),
    )
        values = [
            Float64[getfield(candidate.rows[index], quantity)
                for candidate in all_traces]
            for index in 1:row_count
        ]
        push!(series, "$(label)_minimum_$(unit)" => minimum.(values))
        push!(series, "$(label)_maximum_$(unit)" => maximum.(values))
    end
    kcl_values = [
        Float64[candidate.rows[index].maximum_kcl_residual_a
            for candidate in all_traces]
        for index in 1:row_count
    ]
    push!(series, "maximum_kcl_residual_a" => maximum.(kcl_values))
    return series
end

function _runtime_refinement_diagnostics(
    nominal,
    uncertainty_runs,
    refined_nominal,
    refined_uncertainty_runs,
)
    coarse_runs = [nominal, uncertainty_runs...]
    refined_runs = [refined_nominal, refined_uncertainty_runs...]
    length(coarse_runs) == length(refined_runs) || error(
        "coupled-line runtime refinement scenario count changed",
    )
    coarse_timestep_s = coarse_runs[1].runtime.settings.timestep_s
    refined_timestep_s = refined_runs[1].runtime.settings.timestep_s
    ratio_float = coarse_timestep_s / refined_timestep_s
    refinement_ratio = round(Int, ratio_float)
    refinement_ratio >= 2 && ratio_float == refinement_ratio || error(
        "coupled-line runtime refinement timesteps are not exactly nested",
    )
    all(result -> result.runtime.settings.timestep_s == coarse_timestep_s,
        coarse_runs) || error("coupled-line runtime coarse uncertainty timestep changed")
    all(result -> result.runtime.settings.timestep_s == refined_timestep_s,
        refined_runs) || error("coupled-line runtime refined uncertainty timestep changed")
    coarse_times_s = coarse_runs[1].times_s
    row_count = length(coarse_times_s)
    voltage_difference_v = zeros(row_count)
    current_difference_a = zeros(row_count)
    power_difference_w = zeros(row_count)
    energy_difference_j = zeros(row_count)
    coarse_kcl_residual_a = zeros(row_count)
    refined_kcl_residual_a = zeros(row_count)
    for coarse_index in 1:row_count
        refined_index = 1 + (coarse_index - 1) * refinement_ratio
        for (coarse, refined) in zip(coarse_runs, refined_runs)
            refined.times_s[refined_index] == coarse.times_s[coarse_index] || error(
                "coupled-line runtime refinement time grids do not align exactly",
            )
            coarse_row = coarse.rows[coarse_index]
            refined_row = refined.rows[refined_index]
            coarse_row.fault_closed == refined_row.fault_closed || error(
                "coupled-line runtime refinement changed event timing",
            )
            voltage_difference_v[coarse_index] = max(
                voltage_difference_v[coarse_index],
                maximum(abs, coarse_row.receiving_voltage_v -
                    refined_row.receiving_voltage_v),
            )
            current_difference_a[coarse_index] = max(
                current_difference_a[coarse_index],
                maximum(abs, coarse_row.sending_current_a -
                    refined_row.sending_current_a),
                maximum(abs, coarse_row.receiving_current_a -
                    refined_row.receiving_current_a),
            )
            power_difference_w[coarse_index] = max(
                power_difference_w[coarse_index],
                abs(coarse_row.terminal_power_w - refined_row.terminal_power_w),
            )
            energy_difference_j[coarse_index] = max(
                energy_difference_j[coarse_index],
                abs(coarse_row.cumulative_supplied_energy_j -
                    refined_row.cumulative_supplied_energy_j),
            )
            coarse_kcl_residual_a[coarse_index] = max(
                coarse_kcl_residual_a[coarse_index],
                coarse_row.maximum_kcl_residual_a,
            )
            refined_kcl_residual_a[coarse_index] = max(
                refined_kcl_residual_a[coarse_index],
                refined_row.maximum_kcl_residual_a,
            )
        end
    end
    series = [
        "maximum_receiving_voltage_difference_v" => voltage_difference_v,
        "maximum_terminal_current_difference_a" => current_difference_a,
        "maximum_terminal_power_difference_w" => power_difference_w,
        "maximum_cumulative_energy_difference_j" => energy_difference_j,
        "coarse_maximum_kcl_residual_a" => coarse_kcl_residual_a,
        "refined_maximum_kcl_residual_a" => refined_kcl_residual_a,
    ]
    return (
        coarse_timestep_s=coarse_timestep_s,
        refined_timestep_s=refined_timestep_s,
        refinement_ratio=refinement_ratio,
        series=series,
        maximum_voltage_difference_v=maximum(voltage_difference_v),
        maximum_current_difference_a=maximum(current_difference_a),
        maximum_power_difference_w=maximum(power_difference_w),
        maximum_energy_difference_j=maximum(energy_difference_j),
        maximum_coarse_kcl_residual_a=maximum(coarse_kcl_residual_a),
        maximum_refined_kcl_residual_a=maximum(refined_kcl_residual_a),
    )
end

function _write_runtime_outputs(
    output_dir,
    case_id,
    runtime,
    trace,
    restart_exact,
    uncertainty_runs,
    refinement,
)
    times_s = trace.times_s
    phase_count = length(first(trace.rows).receiving_voltage_v)
    waveform_series = Pair{String,Vector{Float64}}[]
    for phase in 1:phase_count
        push!(waveform_series,
            "receiving_voltage_phase_$(phase)_v" =>
                [row.receiving_voltage_v[phase] for row in trace.rows])
        push!(waveform_series,
            "sending_current_phase_$(phase)_a" =>
                [row.sending_current_a[phase] for row in trace.rows])
        push!(waveform_series,
            "receiving_current_phase_$(phase)_a" =>
                [row.receiving_current_a[phase] for row in trace.rows])
    end
    waveform_csv = write_series_csv(
        joinpath(output_dir, "runtime_waveforms.csv"),
        "time_s",
        times_s,
        waveform_series,
    )
    diagnostic_series = [
        "terminal_power_w" => [row.terminal_power_w for row in trace.rows],
        "cumulative_supplied_energy_j" =>
            [row.cumulative_supplied_energy_j for row in trace.rows],
        "maximum_kcl_residual_a" =>
            [row.maximum_kcl_residual_a for row in trace.rows],
        "fault_closed" => [row.fault_closed for row in trace.rows],
    ]
    diagnostic_csv = write_series_csv(
        joinpath(output_dir, "runtime_energy_kcl.csv"),
        "time_s",
        times_s,
        diagnostic_series,
    )
    uncertainty_csv = write_series_csv(
        joinpath(output_dir, "runtime_uncertainty.csv"),
        "time_s",
        times_s,
        _runtime_envelope_series(
            trace,
            [(; times_s=result.times_s, rows=result.rows)
                for result in uncertainty_runs],
        ),
    )
    refinement_csv = write_series_csv(
        joinpath(output_dir, "runtime_refinement.csv"),
        "time_s",
        times_s,
        refinement.series,
    )
    voltage_svg = write_waveform_svg(
        joinpath(output_dir, "runtime_waveforms.svg"),
        times_s,
        [
            "phase $(phase)" =>
                [row.receiving_voltage_v[phase] for row in trace.rows]
            for phase in 1:phase_count
        ];
        title="Coupled Line Receiving-End Voltage",
        x_label="time (s)",
        y_label="voltage (V)",
    )
    energy_svg = write_waveform_svg(
        joinpath(output_dir, "runtime_energy.svg"),
        times_s,
        [
            "cumulative supplied energy" =>
                [row.cumulative_supplied_energy_j for row in trace.rows],
        ];
        title="Coupled Line Supplied Energy",
        x_label="time (s)",
        y_label="energy (J)",
    )
    report_path = joinpath(output_dir, "runtime_report.txt")
    open(report_path, "w") do io
        println(io, "scenario=nominal")
        for (index, line) in enumerate(runtime.lines)
            println(io, "segment_index=", index)
            print(io, coupled_line_runtime_report_text(line.runtime_state))
        end
        for (scenario_index, result) in enumerate(uncertainty_runs)
            println(io, "scenario=uncertainty_alternative_", scenario_index)
            for (segment_index, line) in enumerate(result.runtime.lines)
                println(io, "segment_index=", segment_index)
                print(io, coupled_line_runtime_report_text(line.runtime_state))
            end
        end
    end
    final_rows = last(trace.rows)
    declared_alternative_signatures = [
        signature
        for fit in runtime.fits
        for signature in fit.uncertainty.alternative_fit_signatures_sha256
    ]
    executed_alternative_signatures = [
        fit.deterministic_signature_sha256
        for result in uncertainty_runs
        for fit in result.runtime.fits
    ]
    uncertainty_set_complete = all(
        fit -> fit.uncertainty.complete_set,
        runtime.fits,
    )
    uncertainty_rows = copy(trace.rows)
    for result in uncertainty_runs
        append!(uncertainty_rows, result.rows)
    end
    uncertainty_maximum_absolute_receiving_voltage_v = maximum(
        row -> maximum(abs, row.receiving_voltage_v),
        uncertainty_rows,
    )
    uncertainty_maximum_absolute_terminal_current_a = maximum(
        row -> max(
            maximum(abs, row.sending_current_a),
            maximum(abs, row.receiving_current_a),
        ),
        uncertainty_rows,
    )
    uncertainty_maximum_kcl_residual_a = maximum(
        row -> row.maximum_kcl_residual_a,
        uncertainty_rows,
    )
    uncertainty_minimum_cumulative_supplied_energy_j = minimum(
        row -> row.cumulative_supplied_energy_j,
        uncertainty_rows,
    )
    summary = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Coupled Frequency-Dependent Line Runtime",
        (
            case_id=case_id,
            representation="complete_coupled_phase_domain_l205_runtime",
            uniform_segment_count=length(runtime.lines),
            separately_executed_uniform_segments=true,
            timestep_s=first(runtime.preparations).settings.timestep_s,
            end_time_s=COUPLED_LINE_RUNTIME_END_TIME_S,
            initialization="discrete_sinusoidal_operating_point",
            fault_start_s=COUPLED_LINE_RUNTIME_FAULT_START_S,
            fault_end_s=COUPLED_LINE_RUNTIME_FAULT_END_S,
            restart_exact=restart_exact,
            uncertainty_alternative_count=length(uncertainty_runs),
            declared_uncertainty_fit_signatures=join(
                declared_alternative_signatures,
                ",",
            ),
            executed_uncertainty_fit_signatures=join(
                executed_alternative_signatures,
                ",",
            ),
            every_declared_uncertainty_alternative_executed=
                sort(declared_alternative_signatures) ==
                sort(executed_alternative_signatures),
            uncertainty_set_complete=uncertainty_set_complete,
            unknown_uncertainty_explicit=!uncertainty_set_complete,
            refinement_timestep_s=refinement.refined_timestep_s,
            refinement_ratio=refinement.refinement_ratio,
            refinement_maximum_voltage_difference_v=
                refinement.maximum_voltage_difference_v,
            refinement_maximum_current_difference_a=
                refinement.maximum_current_difference_a,
            refinement_maximum_power_difference_w=
                refinement.maximum_power_difference_w,
            refinement_maximum_energy_difference_j=
                refinement.maximum_energy_difference_j,
            refinement_maximum_coarse_kcl_residual_a=
                refinement.maximum_coarse_kcl_residual_a,
            refinement_maximum_fine_kcl_residual_a=
                refinement.maximum_refined_kcl_residual_a,
            uncertainty_maximum_absolute_receiving_voltage_v=
                uncertainty_maximum_absolute_receiving_voltage_v,
            uncertainty_maximum_absolute_terminal_current_a=
                uncertainty_maximum_absolute_terminal_current_a,
            uncertainty_maximum_kcl_residual_a=
                uncertainty_maximum_kcl_residual_a,
            uncertainty_minimum_cumulative_supplied_energy_j=
                uncertainty_minimum_cumulative_supplied_energy_j,
            source_signatures=join(
                (fit.source_signature_sha256 for fit in runtime.fits),
                ",",
            ),
            fit_signatures=join(
                (fit.deterministic_signature_sha256 for fit in runtime.fits),
                ",",
            ),
            runtime_signatures=join(
                (
                    line.runtime_state.preparation.deterministic_signature_sha256
                    for line in runtime.lines
                ),
                ",",
            ),
            maximum_kcl_residual_a=final_rows.maximum_kcl_residual_a,
            cumulative_supplied_energy_j=final_rows.cumulative_supplied_energy_j,
            private_solver_source_in_public_output=false,
            ulm_file_compatibility_claimed=false,
            atp_or_pscad_equivalence_claimed=false,
        ),
    )
    return (; waveform_csv, diagnostic_csv, uncertainty_csv, refinement_csv,
        voltage_svg, energy_svg, report_path=abspath(report_path), summary)
end

function _execute_coupled_line_runtime_trajectory(
    snapshot_dir;
    fit_paths,
    from_node_orders,
    to_node_orders,
    source_nodes,
    receiving_nodes,
    fault_node,
    timestep_s=COUPLED_LINE_RUNTIME_TIMESTEP_S,
)
    runtime = _runtime_network(
        fit_paths,
        from_node_orders,
        to_node_orders,
        source_nodes,
        receiving_nodes,
        fault_node,
        timestep_s,
    )
    step_count = round(Int, COUPLED_LINE_RUNTIME_END_TIME_S /
        timestep_s)
    snapshot_step = step_count ÷ 2
    times_s = collect(0:step_count) .* timestep_s
    rows = [_runtime_trace_row(
        runtime.lines,
        runtime.system.v,
        receiving_nodes,
        runtime.fault_switch,
        0.0,
    )]
    snapshot_paths = String[]
    for step in 1:step_count
        time_s = step * timestep_s
        solve_algebraic_state!(
            runtime.system,
            time_s,
            timestep_s,
        )
        accept_algebraic_state!(
            runtime.system,
            timestep_s,
        )
        push!(rows, _runtime_trace_row(
            runtime.lines,
            runtime.system.v,
            receiving_nodes,
            runtime.fault_switch,
            time_s,
        ))
        if step == snapshot_step
            for (index, line) in enumerate(runtime.lines)
                push!(snapshot_paths,
                    write_coupled_frequency_dependent_line_snapshot(
                        joinpath(snapshot_dir, "runtime_snapshot_segment_$(index).toml"),
                        coupled_frequency_dependent_line_snapshot(line),
                    ))
            end
        end
    end
    final_signatures = [
        coupled_frequency_dependent_line_snapshot(line).runtime_snapshot.deterministic_signature_sha256
        for line in runtime.lines
    ]

    replay = _runtime_network(
        fit_paths,
        from_node_orders,
        to_node_orders,
        source_nodes,
        receiving_nodes,
        fault_node,
        timestep_s,
    )
    for (line, path) in zip(replay.lines, snapshot_paths)
        restore_coupled_frequency_dependent_line_snapshot!(
            line,
            read_coupled_frequency_dependent_line_snapshot(path),
        )
    end
    for step in (snapshot_step + 1):step_count
        time_s = step * timestep_s
        solve_algebraic_state!(
            replay.system,
            time_s,
            timestep_s,
        )
        accept_algebraic_state!(
            replay.system,
            timestep_s,
        )
    end
    replay_signatures = [
        coupled_frequency_dependent_line_snapshot(line).runtime_snapshot.deterministic_signature_sha256
        for line in replay.lines
    ]
    restart_exact = replay_signatures == final_signatures &&
        replay.system.v == runtime.system.v
    restart_exact || error("public coupled-line runtime restart did not replay exactly")
    maximum(row.maximum_kcl_residual_a for row in rows) <= 1.0e-6 ||
        error("public coupled-line runtime KCL residual exceeded its product limit")
    all(isfinite, reduce(vcat, (row.receiving_voltage_v for row in rows))) ||
        error("public coupled-line runtime produced a nonfinite voltage")
    return (; runtime, replay, times_s, rows, snapshot_paths, restart_exact)
end

function _verify_runtime_uncertainty_contract(nominal_runtime, alternative_runtime)
    length(nominal_runtime.fits) == length(alternative_runtime.fits) ||
        error("coupled-line runtime uncertainty segment count changed")
    for (segment_index, (nominal_fit, alternative_fit)) in enumerate(zip(
        nominal_runtime.fits,
        alternative_runtime.fits,
    ))
        uncertainty = nominal_fit.uncertainty
        uncertainty === nothing && error(
            "coupled-line runtime segment $(segment_index) has no declared L205 uncertainty",
        )
        alternative_index = findfirst(
            ==(alternative_fit.deterministic_signature_sha256),
            uncertainty.alternative_fit_signatures_sha256,
        )
        alternative_index === nothing && error(
            "coupled-line runtime segment $(segment_index) executed an undeclared L205 alternative",
        )
        alternative_fit.source_signature_sha256 ==
            uncertainty.alternative_source_signatures_sha256[alternative_index] ||
            error(
                "coupled-line runtime segment $(segment_index) alternative source identity changed",
            )
        nominal_response = nominal_fit.source_response
        alternative_response = alternative_fit.source_response
        for field in (
            :segment_id,
            :segment_kind,
            :length_m,
            :frequencies_hz,
            :phase_order,
            :port_order,
            :reference_impedance_ohm,
        )
            getfield(alternative_response, field) == getfield(nominal_response, field) ||
                error(
                    "coupled-line runtime segment $(segment_index) alternative changed $(field)",
                )
        end
        alternative_fit.settings_signature_sha256 ==
            nominal_fit.settings_signature_sha256 || error(
                "coupled-line runtime segment $(segment_index) alternative fit settings changed",
            )
        alternative_fit.certificate_after_enforcement.continuous_passivity_passed ||
            error(
                "coupled-line runtime segment $(segment_index) alternative is not continuously passive",
            )
    end
    return nothing
end

function run_coupled_line_runtime_example(
    output_dir;
    case_id,
    fit_paths,
    alternative_fit_path_sets,
    from_node_orders,
    to_node_orders,
    source_nodes,
    receiving_nodes,
    fault_node,
)
    isempty(alternative_fit_path_sets) && error(
        "public coupled-line runtime products must execute their declared uncertainty alternatives",
    )
    nominal = _execute_coupled_line_runtime_trajectory(
        output_dir;
        fit_paths,
        from_node_orders,
        to_node_orders,
        source_nodes,
        receiving_nodes,
        fault_node,
    )
    uncertainty_runs = Any[]
    for alternative_fit_paths in alternative_fit_path_sets
        length(alternative_fit_paths) == length(fit_paths) || error(
            "coupled-line runtime uncertainty path set does not cover every segment",
        )
        result = mktempdir() do snapshot_dir
            _execute_coupled_line_runtime_trajectory(
                snapshot_dir;
                fit_paths=alternative_fit_paths,
                from_node_orders,
                to_node_orders,
                source_nodes,
                receiving_nodes,
                fault_node,
            )
        end
        _verify_runtime_uncertainty_contract(nominal.runtime, result.runtime)
        result.restart_exact || error(
            "coupled-line runtime uncertainty alternative did not restart exactly",
        )
        push!(uncertainty_runs, result)
    end
    declared_alternatives = sort([
        signature
        for fit in nominal.runtime.fits
        for signature in fit.uncertainty.alternative_fit_signatures_sha256
    ])
    executed_alternatives = sort([
        fit.deterministic_signature_sha256
        for result in uncertainty_runs
        for fit in result.runtime.fits
    ])
    executed_alternatives == declared_alternatives || error(
        "public coupled-line runtime did not execute every declared uncertainty alternative exactly once",
    )
    refined_timestep_s = COUPLED_LINE_RUNTIME_TIMESTEP_S / 2.0
    refined_nominal = mktempdir() do snapshot_dir
        _execute_coupled_line_runtime_trajectory(
            snapshot_dir;
            fit_paths,
            from_node_orders,
            to_node_orders,
            source_nodes,
            receiving_nodes,
            fault_node,
            timestep_s=refined_timestep_s,
        )
    end
    refined_nominal.restart_exact || error(
        "coupled-line runtime refined nominal trajectory did not restart exactly",
    )
    refined_uncertainty_runs = Any[]
    for alternative_fit_paths in alternative_fit_path_sets
        result = mktempdir() do snapshot_dir
            _execute_coupled_line_runtime_trajectory(
                snapshot_dir;
                fit_paths=alternative_fit_paths,
                from_node_orders,
                to_node_orders,
                source_nodes,
                receiving_nodes,
                fault_node,
                timestep_s=refined_timestep_s,
            )
        end
        _verify_runtime_uncertainty_contract(refined_nominal.runtime, result.runtime)
        result.restart_exact || error(
            "coupled-line runtime refined uncertainty trajectory did not restart exactly",
        )
        push!(refined_uncertainty_runs, result)
    end
    refinement = _runtime_refinement_diagnostics(
        nominal,
        uncertainty_runs,
        refined_nominal,
        refined_uncertainty_runs,
    )
    artifacts = _write_runtime_outputs(
        output_dir,
        case_id,
        nominal.runtime,
        (; times_s=nominal.times_s, rows=nominal.rows),
        nominal.restart_exact,
        uncertainty_runs,
        refinement,
    )
    return merge(nominal, (;
        uncertainty_runs,
        refined_nominal,
        refined_uncertainty_runs,
        refinement,
        artifacts,
    ))
end
