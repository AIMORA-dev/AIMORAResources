#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy
using AIMORA.StudyCore
using .ExampleSupport

const TIMESTEP_S = 500.0e-6
const FUNDAMENTAL_FREQUENCY_HZ = 50.0
const FREQUENCY_GRID_HZ = [10.0, 50.0, 70.0]
const PROJECT_SIGNATURE = "public-consistent-initialization-project-v1"
const SETTINGS_SIGNATURE = "public-consistent-initialization-settings-v1"
const MODEL_SIGNATURE = "public-consistent-initialization-model-v1"

function initialization_request(formulation; operating_point=nothing)
    return EMTInitializationRequest(
        formulation;
        frequency_hz=FUNDAMENTAL_FREQUENCY_HZ,
        frequency_grid_hz=FREQUENCY_GRID_HZ,
        operating_point,
        project_signature=PROJECT_SIGNATURE,
        settings_signature=SETTINGS_SIGNATURE,
        model_signature=MODEL_SIGNATURE,
    )
end

function require_condition(condition::Bool, message::AbstractString)
    condition || error(message)
    return nothing
end

function write_frequency_scan(path, labeled_results)
    open(path, "w") do io
        println(io, "formulation,frequency_hz,reactive_angular_frequency_rad_s,node,voltage_real_v,voltage_imaginary_v,topology,rank,reduced_nodes,condition_estimate,maximum_residual_a,symmetry_error_s,minimum_dissipative_eigenvalue_s,passed")
        for (label, result) in labeled_results
            node_names = result.prepared.runtime_template.context.node_names
            for point in result.report.frequency_scan
                for node_index in eachindex(node_names)
                    voltage = point.node_voltage_phasors[node_index]
                    @printf(
                        io,
                        "%s,%.12g,%.12g,%s,%.12g,%.12g,%s,%d,%d,%.12g,%.12g,%.12g,%.12g,%s\n",
                        String(label),
                        point.physical_frequency_hz,
                        point.reactive_angular_frequency_rad_s,
                        String(node_names[node_index]),
                        real(voltage),
                        imag(voltage),
                        String(point.topology.classification),
                        point.topology.numerical_rank,
                        point.topology.reduced_node_count,
                        point.topology.condition_estimate,
                        point.topology.maximum_residual_a,
                        point.admittance_symmetry_max_abs_error,
                        point.minimum_dissipative_eigenvalue_s,
                        point.passed,
                    )
                end
            end
        end
    end
    return abspath(path)
end

function fundamental_point(result)
    return only(filter(
        point -> point.physical_frequency_hz == FUNDAMENTAL_FREQUENCY_HZ,
        result.report.frequency_scan,
    ))
end

function write_formulation_comparison(path, physical, timestep_matched)
    physical_point = fundamental_point(physical)
    timestep_point = fundamental_point(timestep_matched)
    node_names = physical.prepared.runtime_template.context.node_names
    open(path, "w") do io
        println(io, "node,physical_real_v,physical_imaginary_v,timestep_matched_real_v,timestep_matched_imaginary_v,absolute_difference_v")
        for node_index in eachindex(node_names)
            physical_voltage = physical_point.node_voltage_phasors[node_index]
            timestep_voltage = timestep_point.node_voltage_phasors[node_index]
            @printf(
                io,
                "%s,%.12g,%.12g,%.12g,%.12g,%.12g\n",
                String(node_names[node_index]),
                real(physical_voltage),
                imag(physical_voltage),
                real(timestep_voltage),
                imag(timestep_voltage),
                abs(physical_voltage - timestep_voltage),
            )
        end
    end
    return abspath(path)
end

function write_state_inventory(path, sequence_run)
    open(path, "w") do io
        println(io, "case_index,owner,state_family,instance_count,initialization_basis")
        for data_case in sequence_run.cases
            for record in data_case.initialization_report.state_inventory
                println(
                    io,
                    join((
                        data_case.case_index,
                        String(record.owner),
                        String(record.state_family),
                        record.instance_count,
                        String(record.initialization_basis),
                    ), ","),
                )
            end
        end
    end
    return abspath(path)
end

function write_operating_point_mapping(path, sequence_run)
    mapped_report = sequence_run.cases[2].initialization_report
    open(path, "w") do io
        println(io, "asset,quantity,phase,source_unit,target_unit,basis,orientation,source_real,source_imaginary,target_real_si,target_imaginary_si,absolute_uncertainty_si,residual_v,reaction_current_real_a,reaction_current_imaginary_a,passed")
        for mapping in mapped_report.mappings
            @printf(
                io,
                "%s,%s,%s,%s,%s,%s,%s,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%.12g,%s\n",
                String(mapping.asset),
                String(mapping.quantity),
                String(mapping.phase),
                mapping.source_unit,
                mapping.target_unit,
                mapping.basis,
                mapping.orientation,
                real(mapping.source_value),
                imag(mapping.source_value),
                real(mapping.target_value_si),
                imag(mapping.target_value_si),
                mapping.absolute_uncertainty_si,
                mapping.residual,
                real(mapping.constraint_current_phasor_a),
                imag(mapping.constraint_current_phasor_a),
                mapping.passed,
            )
        end
    end
    return abspath(path)
end

function main()
    AIMORA.require_solver()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))
    input_path = joinpath(@__DIR__, "consistent_initialization_sequence.deck")
    sequence = parse_deck_case_sequence(
        readlines(input_path);
        source=portable_input_path(input_path),
    )
    require_condition(
        length(sequence.cases) == 2 &&
            all(data_case -> AIMORA.ValidationCore.is_valid(data_case.parsed.validation), sequence.cases),
        "consistent-initialization sequence must contain two valid isolated EMT cases",
    )

    physical = initialize_emt_study(
        sequence.cases[1].parsed,
        initialization_request(PhysicalFrequencyFormulation());
        timestep_s=TIMESTEP_S,
        t_end_s=2.0 * TIMESTEP_S,
    )
    timestep_request = initialization_request(
        TimestepMatchedFormulation(TIMESTEP_S),
    )
    timestep_preview = initialize_emt_study(
        sequence.cases[1].parsed,
        timestep_request;
        t_end_s=2.0 * TIMESTEP_S,
    )
    require_condition(
        initialization_accepted(physical) &&
            initialization_accepted(timestep_preview),
        "physical and timestep-matched initializations must both accept with the declared probe timestep: physical=$(physical.failure), timestep_matched=$(timestep_preview.failure)",
    )

    load_index = sequence.cases[1].parsed.node_map[:load]
    load_target = fundamental_point(timestep_preview).node_voltage_phasors[load_index]
    provenance = ParameterProvenance(
        "AIMORA-authored accepted first-case harmonic equilibrium",
        "V",
        "exact peak node-to-ground phasor",
        "roundoff-only synthetic uncertainty",
        "public passive R-L initialization sequence",
        PhysicalModelParameter,
    )
    operating_quantity = OperatingPointQuantity(
        :load,
        :node_voltage_peak_phasor,
        load_target;
        unit="V",
        basis="peak_node_to_ground",
        orientation="node_to_ground",
        provenance,
    )
    operating_point = EMTOperatingPoint(
        :accepted_emt_initialization,
        PROJECT_SIGNATURE,
        SETTINGS_SIGNATURE,
        MODEL_SIGNATURE,
        FUNDAMENTAL_FREQUENCY_HZ,
        [operating_quantity];
        source_state_signature=
            timestep_preview.report.deterministic_state_signature,
    )
    mapped_request = initialization_request(
        TimestepMatchedFormulation(TIMESTEP_S);
        operating_point,
    )
    sequence_run = run_deck_case_sequence_emt(
        sequence;
        dt_s=TIMESTEP_S,
        t_end_s=2.0 * TIMESTEP_S,
        initializations=Dict(
            1 => DeckCaseInitialization(timestep_request),
            2 => DeckCaseInitialization(
                mapped_request;
                mapped_from_case_index=1,
            ),
        ),
    )
    require_condition(
        sequence_run.initialization_failure_count == 0 &&
            all(data_case -> data_case.execution_kind === :initialized_emt, sequence_run.cases) &&
            all(data_case -> data_case.trace !== nothing, sequence_run.cases),
        "both mapped sequence cases must initialize and execute",
    )
    require_condition(
        sequence_run.cases[1].initialization_report.deterministic_state_signature ==
            timestep_preview.report.deterministic_state_signature &&
            sequence_run.cases[2].initialization_source_case_index == 1,
        "mapped sequence must retain its accepted source-state signature and dependency",
    )

    reports = [data_case.initialization_report for data_case in sequence_run.cases]
    mapping = only(reports[2].mappings)
    all_frequency_points_pass = all(
        point -> point.passed && point.topology.classification === :unique,
        vcat(physical.report.frequency_scan, timestep_preview.report.frequency_scan),
    )
    all_transient_metrics_pass = all(
        metric -> metric.passed,
        vcat((report.transient_metrics for report in reports)...),
    )
    maximum_transient_normalized_rms = maximum(
        metric.normalized_rms
        for report in reports for metric in report.transient_metrics;
        init=0.0,
    )
    require_condition(
        all_frequency_points_pass &&
            all_transient_metrics_pass &&
            mapping.passed &&
            mapping.residual <= 1.0e-12 &&
            abs(mapping.constraint_current_phasor_a) <= 1.0e-10,
        "scan, no-artificial-transient, or operating-point mapping evidence failed",
    )

    frequency_scan_path = write_frequency_scan(
        joinpath(output_dir, "frequency_scan.csv"),
        [
            :physical_frequency => physical,
            :timestep_matched => timestep_preview,
        ],
    )
    formulation_path = write_formulation_comparison(
        joinpath(output_dir, "formulation_comparison.csv"),
        physical,
        timestep_preview,
    )
    state_inventory_path = write_state_inventory(
        joinpath(output_dir, "state_inventory.csv"),
        sequence_run,
    )
    mapping_path = write_operating_point_mapping(
        joinpath(output_dir, "operating_point_mapping.csv"),
        sequence_run,
    )

    first_trace = sequence_run.cases[1].trace
    second_trace = sequence_run.cases[2].trace
    first_load_index = sequence.cases[1].parsed.node_map[:load]
    second_load_index = sequence.cases[2].parsed.node_map[:load]
    waveform_series = [
        "first_case_load_voltage_v" => vec(first_trace.voltage_pu[first_load_index, :]),
        "mapped_second_case_load_voltage_v" =>
            vec(second_trace.voltage_pu[second_load_index, :]),
    ]
    waveform_csv = write_series_csv(
        joinpath(output_dir, "initialized_waveforms.csv"),
        "time_s",
        first_trace.time_s,
        waveform_series,
    )
    waveform_svg = write_waveform_svg(
        joinpath(output_dir, "initialized_waveforms.svg"),
        first_trace.time_s,
        waveform_series;
        title="Consistently Initialized and Mapped EMT Cases",
        y_label="load voltage (V peak)",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Consistent EMT Initialization and Mapped Sequencing",
        (
            julia_only=true,
            case_count=length(sequence_run.cases),
            frequency_grid_hz=join(FREQUENCY_GRID_HZ, ", "),
            physical_scan_points=length(physical.report.frequency_scan),
            timestep_matched_scan_points=
                length(timestep_preview.report.frequency_scan),
            physical_frequency_initialization_status=physical.report.status,
            timestep_matched_initialization_status=timestep_preview.report.status,
            all_frequency_points_pass,
            all_transient_metrics_pass,
            maximum_transient_normalized_rms,
            mapping_residual_v=mapping.residual,
            mapping_reaction_current_a=abs(mapping.constraint_current_phasor_a),
            source_state_signature=
                sequence_run.cases[1].initialization_report.deterministic_state_signature,
            mapped_state_signature=
                sequence_run.cases[2].initialization_report.deterministic_state_signature,
            validity="synthetic passive three-node R-L network; 10/50/70 Hz scan; 500 microsecond timestep; one exact peak node-voltage mapping",
            limitations="not a power-flow replacement, proprietary simulator comparison, equipment recommendation, or certification claim",
        ),
    )

    @printf("Frequency scan: %s\n", frequency_scan_path)
    @printf("Formulation comparison: %s\n", formulation_path)
    @printf("State inventory: %s\n", state_inventory_path)
    @printf("Operating-point mapping: %s\n", mapping_path)
    @printf("Waveform CSV: %s\n", waveform_csv)
    @printf("Waveform SVG: %s\n", waveform_svg)
    @printf("Summary: %s\n", summary_path)
end

main()
