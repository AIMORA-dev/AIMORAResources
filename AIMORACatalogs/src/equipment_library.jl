const EQUIPMENT_LIBRARY_SCHEMA = "aimora-equipment-library-v1"
const EQUIPMENT_LIBRARY_VERSION = "1.0.0"
const EQUIPMENT_LIBRARY_SCOPES = ("system", "user", "project")
const EQUIPMENT_LIBRARY_CATEGORIES = Set((
    "transformer",
    "current_transformer",
    "voltage_transformer",
    "switching",
    "cable",
    "bus",
    "load",
    "grounding",
    "machine",
    "converter",
    "storage",
    "source",
    "annotation",
))

equipment_library_path() = joinpath(package_root(), "equipment", "system.toml")

function _equipment_library_validate(document)
    document["schema"] == EQUIPMENT_LIBRARY_SCHEMA ||
        error("unsupported equipment library schema")
    document["version"] == EQUIPMENT_LIBRARY_VERSION ||
        error("unsupported equipment library version")
    collections = document["collection"]
    scopes = [item["scope"] for item in collections]
    scopes == collect(EQUIPMENT_LIBRARY_SCOPES) ||
        error("equipment library collection order or scope is invalid")
    !collections[1]["mutable"] && all(item["mutable"] for item in collections[2:end]) ||
        error("equipment library collection mutability is invalid")
    equipment = document["equipment"]
    ids = [item["id"] for item in equipment]
    length(ids) == length(unique(ids)) || error("equipment library repeats an ID")
    Set(item["category"] for item in equipment) == EQUIPMENT_LIBRARY_CATEGORIES ||
        error("equipment library does not cover every required category")
    all(item["scope"] in EQUIPMENT_LIBRARY_SCOPES for item in equipment) ||
        error("equipment library uses an unknown collection scope")
    all(!isempty(item["symbol_id"]) for item in equipment) ||
        error("equipment library item lacks a symbol")
    all(!isempty(get(item, "part", Any[])) for item in equipment) ||
        error("equipment library item lacks parts-list data")
    assemblies = get(document, "assembly", Any[])
    assembly_ids = [item["id"] for item in assemblies]
    length(assembly_ids) == length(unique(assembly_ids)) ||
        error("equipment library repeats an assembly ID")
    known_equipment = Set(ids)
    for assembly in assemblies
        members = assembly["member"]
        local_ids = Set(member["id"] for member in members)
        length(local_ids) == length(members) || error("assembly repeats a member ID")
        all(member["equipment_id"] in known_equipment for member in members) ||
            error("assembly references unknown equipment")
        for member in members
            parent = get(member, "parent", nothing)
            parent === nothing || parent in local_ids ||
                error("assembly references an unknown parent")
            all(
                reference["target"] in local_ids
                for reference in get(member, "cross_reference", Any[])
            ) || error("assembly contains an unknown cross-reference")
        end
    end
    return document
end

equipment_library_document() =
    _equipment_library_validate(TOML.parsefile(equipment_library_path()))

_native_part(part) = Dict{String,Any}(
    "number" => String(part["number"]),
    "description" => String(part["description"]),
    "unit" => String(part["unit"]),
    "quantity" => Int(part["quantity"]),
)

function _assembly_parts(assembly, equipment_by_id)
    totals = Dict{Tuple{String,String,String},Int}()
    for member in assembly["member"], part in equipment_by_id[member["equipment_id"]]["part"]
        key = (
            String(part["number"]),
            String(part["description"]),
            String(part["unit"]),
        )
        totals[key] = get(totals, key, 0) + Int(part["quantity"])
    end
    return Any[
        Dict{String,Any}(
            "number" => number,
            "description" => description,
            "unit" => unit,
            "quantity" => quantity,
        )
        for ((number, description, unit), quantity) in sort!(collect(totals); by = first)
    ]
end

function native_equipment_library_document()
    document = equipment_library_document()
    equipment_by_id = Dict(item["id"] => item for item in document["equipment"])
    entries = Any[]
    for item in document["equipment"]
        push!(
            entries,
            Dict{String,Any}(
                "kind" => "equipment",
                "id" => item["id"],
                "scope" => item["scope"],
                "category" => item["category"],
                "label" => item["label"],
                "description" => item["description"],
                "equipment_class" => item["equipment_class"],
                "symbol_id" => item["symbol_id"],
                "designator_prefix" => item["designator_prefix"],
                "keywords" => copy(get(item, "keywords", Any[])),
                "parts" => Any[_native_part(part) for part in item["part"]],
                "member_count" => 0,
            ),
        )
    end
    for item in get(document, "assembly", Any[])
        push!(
            entries,
            Dict{String,Any}(
                "kind" => "assembly",
                "id" => item["id"],
                "scope" => item["scope"],
                "category" => item["category"],
                "label" => item["label"],
                "description" => item["description"],
                "equipment_class" => "",
                "symbol_id" => "",
                "designator_prefix" => "",
                "keywords" => copy(get(item, "keywords", Any[])),
                "parts" => _assembly_parts(item, equipment_by_id),
                "member_count" => length(item["member"]),
            ),
        )
    end
    sort!(entries; by = item -> (item["label"], item["id"]))
    return Dict{String,Any}(
        "schema" => document["schema"],
        "version" => document["version"],
        "source_owner" => "AIMORAResources/AIMORACatalogs",
        "collections" => Any[
            Dict{String,Any}(
                "scope" => collection["scope"],
                "mutable" => collection["mutable"],
                "count" => count(
                    entry -> entry["scope"] == collection["scope"],
                    entries,
                ),
            )
            for collection in document["collection"]
        ],
        "entries" => entries,
    )
end
