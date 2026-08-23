#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA
using LinearAlgebra

const AIMORA_EXAMPLE_SOLVER_PATH = let
    configured = get(ENV, "AIMORA_SOLVER_PATH", "")
    candidate = isempty(AIMORA_EXAMPLE_ENGINE_PATH) ? "" :
        joinpath(dirname(AIMORA_EXAMPLE_ENGINE_PATH), "AIMORASolvers.jl")
    if !isempty(configured)
        abspath(configured)
    elseif !isempty(candidate) && isfile(joinpath(candidate, "src", "AIMORASolvers.jl"))
        candidate
    else
        ""
    end
end

if !isempty(AIMORA_EXAMPLE_SOLVER_PATH)
    pushfirst!(LOAD_PATH, AIMORA_EXAMPLE_SOLVER_PATH)
end

using AIMORASolvers

AIMORA.solver_available() || AIMORA.activate_solver!(
    AIMORASolvers.production_backend(),
)

include(normpath(joinpath(@__DIR__, "ExampleSupport.jl")))

using AIMORA.Lines
using .ExampleSupport

function line_parameter_example_source(owner)
    return generic_line_parameter_source(owner; units="SI")
end

function example_soil(source; resistivity_ohm_m=100.0)
    return LineSoilProfile(resistivity_ohm_m; source)
end

function example_overhead_segment(source, soil; id=:overhead, length_m=1000.0,
    phase_order=[:phase_a, :phase_b, :phase_c],
    frequencies_hz=[10.0, 60.0, 600.0, 6000.0])
    conductors = [
        OverheadLineConductor(1, 0.0, 0.20, 4, 0.0, 0.024, -4.0, 15.0),
        OverheadLineConductor(2, 0.0, 0.20, 4, 0.0, 0.024, 0.0, 15.0),
        OverheadLineConductor(3, 0.0, 0.20, 4, 0.0, 0.024, 4.0, 15.0),
    ]
    return overhead_line_parameter_segment(
        id,
        conductors,
        soil,
        frequencies_hz;
        length_m,
        phase_order,
        source,
    )
end

function example_cable_segment(source, soil; id=:cable, length_m=500.0,
    phase_order=[:phase_a, :phase_b, :phase_c],
    frequencies_hz=[10.0, 60.0, 600.0, 6000.0])
    geometry = cable_geometry_constants([
        CableGeometryConductor(0.012, -0.18, 1.2; relative_permittivity=2.3),
        CableGeometryConductor(0.012, 0.0, 1.2; relative_permittivity=2.3),
        CableGeometryConductor(0.012, 0.18, 1.2; relative_permittivity=2.3),
    ])
    return cable_line_parameter_segment(
        id,
        geometry,
        soil,
        frequencies_hz;
        length_m,
        phase_order,
        relative_permittivity=2.3,
        source,
    )
end

function _coupled_line_fit_response_and_modal(segment)
    fitting = AIMORA.CoupledLineFitting
    response = fitting.coupled_line_terminal_response(
        segment;
        reference_impedance_ohm=fill(50.0, 2 * length(segment.phase_order)),
    )
    modal = fitting.coupled_line_modal_preparation(
        segment.frequencies_hz,
        segment.series_impedance_matrices_ohm_per_m,
        segment.shunt_admittance_matrices_s_per_m,
        segment.length_m;
        phase_order=segment.phase_order,
    )
    return response, modal
end

function prepare_coupled_line_fit(
    segment;
    candidate_orders=[20, 40, 60, 80],
    uncertainty_segments=typeof(segment)[],
    uncertainty_set_complete=false,
)
    fitting = AIMORA.CoupledLineFitting
    response, modal = _coupled_line_fit_response_and_modal(segment)
    settings = fitting.CoupledLineFitSettings(
        candidate_orders=candidate_orders,
        relative_fit_tolerance=0.05,
        maximum_direct_term_singular_value=0.92,
        maximum_enforcement_relative_perturbation=0.02,
        maximum_relocation_sweeps=64,
    )
    alternatives = fitting.CoupledLineFitAlternative[]
    for alternative_segment in uncertainty_segments
        alternative_response, alternative_modal =
            _coupled_line_fit_response_and_modal(alternative_segment)
        push!(
            alternatives,
            fitting.CoupledLineFitAlternative(alternative_response, alternative_modal),
        )
    end
    result = AIMORA.prepare_line_fit(fitting.CoupledLineFitRequest(
        response,
        settings,
        modal,
        alternatives,
        uncertainty_set_complete,
    ))
    return (; response, result)
end

function write_coupled_line_fit_artifacts(
    output_dir,
    segment;
    prefix="coupled_line",
    uncertainty_segments=typeof(segment)[],
    uncertainty_set_complete=false,
)
    fitting = AIMORA.CoupledLineFitting
    response, result = prepare_coupled_line_fit(
        segment;
        uncertainty_segments,
        uncertainty_set_complete,
    )
    fit_path = fitting.write_coupled_line_fit(
        joinpath(output_dir, "$(prefix)_fit.toml"),
        result,
    )
    report_path = fitting.write_coupled_line_fit_report(
        joinpath(output_dir, "$(prefix)_fit_report.txt"),
        result,
    )
    source_norm = opnorm.(response.scattering_matrices)
    fitted_norm = opnorm.(result.fitted_scattering_matrices)
    relative_error = [
        opnorm(result.fitted_scattering_matrices[index] - response.scattering_matrices[index]) /
            max(source_norm[index], 1.0e-12)
        for index in eachindex(response.frequencies_hz)
    ]
    maximum_singular_value = [
        maximum(svdvals(matrix); init=0.0)
        for matrix in result.fitted_scattering_matrices
    ]
    minimum_loss_eigenvalue_s = [
        eigmin(Hermitian((matrix + adjoint(matrix)) / 2.0))
        for matrix in result.fitted_terminal_admittance_matrices_s
    ]
    logarithmic_frequency = log10.(response.frequencies_hz)
    response_csv = write_series_csv(
        joinpath(output_dir, "$(prefix)_response.csv"),
        "frequency_hz",
        response.frequencies_hz,
        ["source_scattering_spectral_norm" => source_norm,
         "fitted_scattering_spectral_norm" => fitted_norm],
    )
    response_svg = write_waveform_svg(
        joinpath(output_dir, "$(prefix)_response.svg"),
        logarithmic_frequency,
        ["source" => source_norm, "fit" => fitted_norm];
        title="Coupled Terminal Response",
        x_label="log10 frequency (Hz)",
        y_label="scattering spectral norm",
    )
    error_csv = write_series_csv(
        joinpath(output_dir, "$(prefix)_error.csv"),
        "frequency_hz",
        response.frequencies_hz,
        ["relative_spectral_error" => relative_error],
    )
    error_svg = write_waveform_svg(
        joinpath(output_dir, "$(prefix)_error.svg"),
        logarithmic_frequency,
        ["relative spectral error" => relative_error];
        title="Coupled Fit Error",
        x_label="log10 frequency (Hz)",
        y_label="relative error",
    )
    passivity_csv = write_series_csv(
        joinpath(output_dir, "$(prefix)_passivity.csv"),
        "frequency_hz",
        response.frequencies_hz,
        ["maximum_scattering_singular_value" => maximum_singular_value,
         "minimum_admittance_loss_eigenvalue_s" => minimum_loss_eigenvalue_s],
    )
    passivity_svg = write_waveform_svg(
        joinpath(output_dir, "$(prefix)_passivity.svg"),
        logarithmic_frequency,
        ["maximum singular value" => maximum_singular_value];
        title="Sampled Passivity Diagnostic",
        x_label="log10 frequency (Hz)",
        y_label="maximum scattering singular value",
    )
    result.certificate_after_enforcement.continuous_passivity_passed ||
        error("continuous global passivity certificate failed")
    result.maximum_relative_fit_error <= 0.05 || error("fit accuracy limit failed")
    result.enforcement.admittance_maximum_relative_perturbation <= 0.02 ||
        error("physical-admittance perturbation limit failed")
    return (; fit_path, report_path, response_csv, response_svg, error_csv, error_svg,
        passivity_csv, passivity_svg, result)
end

function write_line_parameter_artifacts(output_dir, parameters)
    report = write_line_parameter_report(
        joinpath(output_dir, "line_parameter_report.txt"),
        parameters,
    )
    interchange = write_line_parameter_set(
        joinpath(output_dir, "line_parameters.toml"),
        parameters,
    )
    frequencies = parameters.frequencies_hz
    diagonal = [
        abs(parameters.average_series_impedance_matrices_ohm_per_m[index][1, 1])
        for index in eachindex(frequencies)
    ]
    mutual = [
        abs(parameters.average_series_impedance_matrices_ohm_per_m[index][1, 2])
        for index in eachindex(frequencies)
    ]
    csv = write_series_csv(
        joinpath(output_dir, "frequency_scan.csv"),
        "frequency_hz",
        frequencies,
        ["diagonal_z_ohm_per_m" => diagonal, "mutual_z_ohm_per_m" => mutual],
    )
    svg = write_waveform_svg(
        joinpath(output_dir, "frequency_scan.svg"),
        log10.(frequencies),
        ["diagonal_z_ohm_per_m" => diagonal, "mutual_z_ohm_per_m" => mutual];
        title="Wideband Line Parameter Magnitudes",
        x_label="log10 frequency (Hz)",
        y_label="impedance magnitude (ohm/m)",
    )
    matrix = write_matrix_csv(
        joinpath(output_dir, "series_impedance_60hz.csv"),
        parameters.average_series_impedance_matrices_ohm_per_m[2];
        row_prefix="phase",
        column_prefix="phase",
    )
    return (; report, interchange, csv, svg, matrix)
end
