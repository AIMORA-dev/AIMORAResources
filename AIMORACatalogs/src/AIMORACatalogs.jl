module AIMORACatalogs

using TOML

export CatalogEntry,
       StudyFacet,
       equipment_library_document,
       native_equipment_library_document,
       available_assets,
       asset,
       asset_path,
       study_facet,
       study_tabs

include("equipment_library.jl")

struct StudyFacet
    study::Symbol
    parameters::Dict{Symbol,Any}
end

struct CatalogEntry
    id::Symbol
    equipment_class::Symbol
    manufacturer::Union{Nothing,String}
    model::String
    provenance::String
    licence::String
    common::Dict{Symbol,Any}
    facets::Dict{Symbol,StudyFacet}
end

package_root() = normpath(joinpath(@__DIR__, ".."))
catalog_root() = joinpath(package_root(), "catalogs")

function asset_paths()
    paths = String[]
    for (directory, _, files) in walkdir(catalog_root())
        for file in files
            endswith(file, ".toml") || continue
            push!(paths, joinpath(directory, file))
        end
    end
    return sort!(paths)
end

symbol_dict(data::AbstractDict) =
    Dict{Symbol,Any}(Symbol(key) => value for (key, value) in data)

function load_asset(path::AbstractString)
    data = TOML.parsefile(path)
    common = symbol_dict(data["common"])
    facets = Dict{Symbol,StudyFacet}()
    for (study_name, parameters) in get(data, "study", Dict{String,Any}())
        study = Symbol(study_name)
        facets[study] = StudyFacet(study, symbol_dict(parameters))
    end
    entry = CatalogEntry(
        Symbol(data["id"]),
        Symbol(data["equipment_class"]),
        isempty(get(data, "manufacturer", "")) ? nothing : String(data["manufacturer"]),
        String(data["model"]),
        String(data["provenance"]),
        String(data["licence"]),
        common,
        facets,
    )
    isempty(entry.provenance) && error("Catalog entry $(entry.id) lacks provenance")
    isempty(entry.licence) && error("Catalog entry $(entry.id) lacks a licence")
    isempty(entry.facets) && error("Catalog entry $(entry.id) has no study facets")
    return entry
end

available_assets() = sort!([load_asset(path) for path in asset_paths()]; by = entry -> String(entry.id))

function asset(id::Symbol)
    entries = available_assets()
    index = findfirst(entry -> entry.id == id, entries)
    index === nothing && throw(KeyError(id))
    return entries[index]
end

function asset_path(id::Symbol)
    path = findfirst(path -> Symbol(TOML.parsefile(path)["id"]) == id, asset_paths())
    path === nothing && throw(KeyError(id))
    return asset_paths()[path]
end

function study_facet(entry::CatalogEntry, study::Symbol)
    facet = get(entry.facets, study, nothing)
    facet === nothing && throw(KeyError(study))
    return facet
end

study_tabs(entry::CatalogEntry) = sort!(collect(keys(entry.facets)); by = String)

end
