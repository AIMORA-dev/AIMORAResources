#!/usr/bin/env julia

using Printf

include(normpath(joinpath(@__DIR__, "..", "..", "load_aimora.jl")))
include(normpath(joinpath(@__DIR__, "..", "..", "support", "ExampleSupport.jl")))

using AIMORA
using .ExampleSupport

function write_study_catalog(path, studies)
    open(path, "w") do io
        println(io, "id,name,domain,status,owner")
        for study in studies
            @printf(
                io,
                "%s,%s,%s,%s,%s\n",
                study.id,
                replace(study.name, "," => ";"),
                study.domain,
                study.status,
                study.source_path,
            )
        end
    end
    return abspath(path)
end

function write_inverters(path, rows)
    open(path, "w") do io
        println(io, "id,bus,rated_kva,v_ll_rms_v,p_ref_pu,q_ref_pu,enabled,model")
        for row in rows
            @printf(
                io,
                "%s,%s,%.12g,%.12g,%.12g,%.12g,%s,%s\n",
                row[:id],
                row[:bus],
                row[:rated_kva],
                row[:v_ll_rms_v],
                row[:p_ref_pu],
                row[:q_ref_pu],
                row[:enabled],
                row[:model],
            )
        end
    end
    return abspath(path)
end

function write_input_profile(path, profile)
    open(path, "w") do io
        println(io, "requirement,key,label,unit,description")
        for (requirement, specifications) in (
            "required" => profile.required,
            "optional" => profile.optional,
        )
            for specification in specifications
                @printf(
                    io,
                    "%s,%s,%s,%s,%s\n",
                    requirement,
                    specification.key,
                    replace(specification.label, "," => ";"),
                    something(specification.unit, ""),
                    replace(specification.description, "," => ";"),
                )
            end
        end
    end
    return abspath(path)
end

function main()
    output_dir = artifact_directory(ARGS, joinpath(@__DIR__, "outputs"))

    project = AIMORA.ProjectData.Project(id = :tutorial, name = "Tutorial Project")
    case = AIMORA.ProjectData.Case(id = :normal_operation, name = "Normal Operation")
    scenario = AIMORA.ProjectData.Scenario(id = :base, name = "Base Scenario")
    AIMORA.ProjectData.add_case!(project, case)
    AIMORA.ProjectData.add_scenario!(case, scenario)
    AIMORA.ProjectData.set_study_settings!(
        scenario,
        AIMORA.ProjectData.StudySettings(
            study = :emt,
            parameters = Dict(:dt_s => 20.0e-6, :duration_s => 20.0e-3),
        ),
    )

    inverter_rows = [
        AIMORA.InverterAssets.inverter_row(
            id = :solar_1,
            bus = :bus_650,
            rated_kva = 750.0,
            v_ll_rms_v = 4160.0,
            p_ref_pu = 0.80,
            q_ref_pu = 0.05,
        ),
        AIMORA.InverterAssets.inverter_row(
            id = :battery_1,
            bus = :bus_675,
            rated_kva = 500.0,
            v_ll_rms_v = 4160.0,
            p_ref_pu = 0.25,
            q_ref_pu = -0.10,
        ),
    ]
    AIMORA.InverterAssets.set_inverter_table!(scenario, inverter_rows)

    studies = AIMORA.StudyCatalog.available_studies()
    implemented = AIMORA.StudyCatalog.implemented_studies()
    profile = AIMORA.StudyInputProfiles.input_profile(:emt)
    required = AIMORA.StudyInputs.required_keys(profile)
    :timestep in required || error("EMT input profile lost the timestep requirement")
    :network_elements in required ||
        error("EMT input profile lost the network-elements requirement")

    catalog_path = write_study_catalog(
        joinpath(output_dir, "study_catalog.csv"),
        studies,
    )
    inverter_path = write_inverters(
        joinpath(output_dir, "inverter_assets.csv"),
        AIMORA.InverterAssets.inverter_table(scenario),
    )
    profile_path = write_input_profile(
        joinpath(output_dir, "emt_input_profile.csv"),
        profile,
    )
    status_index = collect(1:length(studies))
    implemented_count = cumsum([study.status == :implemented for study in studies])
    planned_count = cumsum([study.status == :planned for study in studies])
    plot_path = write_waveform_svg(
        joinpath(output_dir, "study_status.svg"),
        status_index,
        [
            "implemented" => implemented_count,
            "planned" => planned_count,
        ];
        title = "AIMORA Study Catalog Status",
        x_label = "catalog row",
        y_label = "cumulative studies",
    )
    summary_path = write_key_value_summary(
        joinpath(output_dir, "summary.md"),
        "Study Catalog and Scenario Data",
        (
            project = project.id,
            case = case.id,
            scenario = scenario.id,
            inverter_count = length(AIMORA.InverterAssets.inverter_table(scenario)),
            advertised_studies = length(studies),
            implemented_studies = join(string.(getfield.(implemented, :id)), ", "),
            emt_required_inputs = join(string.(required), ", "),
            julia_only = true,
        ),
    )

    @printf("Study catalog: %s\n", catalog_path)
    @printf("Inverter assets: %s\n", inverter_path)
    @printf("EMT input profile: %s\n", profile_path)
    @printf("Status plot: %s\n", plot_path)
    @printf("Summary: %s\n", summary_path)
end

main()
