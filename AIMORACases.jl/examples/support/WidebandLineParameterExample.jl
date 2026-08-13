#!/usr/bin/env julia

include(normpath(joinpath(@__DIR__, "..", "load_aimora.jl")))

using AIMORA

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
    phase_order=[:phase_a, :phase_b, :phase_c])
    conductors = [
        OverheadLineConductor(1, 0.0, 0.20, 4, 0.0, 0.024, -4.0, 15.0),
        OverheadLineConductor(2, 0.0, 0.20, 4, 0.0, 0.024, 0.0, 15.0),
        OverheadLineConductor(3, 0.0, 0.20, 4, 0.0, 0.024, 4.0, 15.0),
    ]
    return overhead_line_parameter_segment(
        id,
        conductors,
        soil,
        [10.0, 60.0, 600.0, 6000.0];
        length_m,
        phase_order,
        source,
    )
end

function example_cable_segment(source, soil; id=:cable, length_m=500.0,
    phase_order=[:phase_a, :phase_b, :phase_c])
    geometry = cable_geometry_constants([
        CableGeometryConductor(0.012, -0.18, 1.2; relative_permittivity=2.3),
        CableGeometryConductor(0.012, 0.0, 1.2; relative_permittivity=2.3),
        CableGeometryConductor(0.012, 0.18, 1.2; relative_permittivity=2.3),
    ])
    return cable_line_parameter_segment(
        id,
        geometry,
        soil,
        [10.0, 60.0, 600.0, 6000.0];
        length_m,
        phase_order,
        relative_permittivity=2.3,
        source,
    )
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
