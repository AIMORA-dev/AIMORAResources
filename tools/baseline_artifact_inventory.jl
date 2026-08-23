module BaselineArtifactInventory

using SHA
using TOML

export artifact_inventory, render_inventory, verify_inventory, write_inventory

const RESOURCE_ROOT = normpath(joinpath(@__DIR__, ".."))
const POLICY_PATH = joinpath(RESOURCE_ROOT, "artifact-policy.toml")
const INVENTORY_PATH = joinpath(RESOURCE_ROOT, "baseline-artifacts.toml")
const ARTIFACT_SUFFIXES = (".csv", ".svg", ".aimora", ".aimora-snapshot")

function git_output(arguments::AbstractString...)
    return read(Cmd(vcat(["git", "-C", RESOURCE_ROOT], collect(String, arguments))), String)
end

function baseline_tree_rows(revision::AbstractString)
    output = git_output("ls-tree", "-rz", "--full-tree", revision)
    rows = NamedTuple{(:path, :blob),Tuple{String,String}}[]
    for record in split(output, '\0'; keepempty = false)
        metadata, path = split(record, '\t'; limit = 2)
        fields = split(metadata)
        length(fields) == 3 || error("unexpected Git tree row: $(metadata)")
        fields[2] == "blob" || continue
        lowercase_path = lowercase(path)
        any(suffix -> endswith(lowercase_path, suffix), ARTIFACT_SUFFIXES) || continue
        push!(rows, (path = path, blob = fields[3]))
    end
    sort!(rows; by = row -> row.path)
    return rows
end

function artifact_classification(path::AbstractString)
    lowercase_path = lowercase(path)
    !occursin("/outputs/", lowercase_path) && return "canonical-input"
    endswith(lowercase_path, ".svg") && return "curated-public-output"
    any(suffix -> endswith(lowercase_path, suffix), (".aimora", ".aimora-snapshot")) &&
        return "immutable-reference"
    return "reproducible-generated-output"
end

function blob_size(blob::AbstractString)
    return parse(Int, strip(git_output("cat-file", "-s", blob)))
end

function inventory_signature(artifacts)
    context = IOBuffer()
    for artifact in artifacts
        print(
            context,
            artifact["path"], '\0',
            artifact["blob"], '\0',
            artifact["classification"], '\0',
            artifact["bytes"], '\n',
        )
    end
    return bytes2hex(sha256(take!(context)))
end

function artifact_inventory()
    policy = TOML.parsefile(POLICY_PATH)
    revision = String(policy["baseline"]["cases_commit"])
    artifacts = Dict{String,Any}[]
    for row in baseline_tree_rows(revision)
        push!(artifacts, Dict{String,Any}(
            "path" => row.path,
            "blob" => row.blob,
            "bytes" => blob_size(row.blob),
            "classification" => artifact_classification(row.path),
            "state" => "retained",
        ))
    end
    counts = Dict{String,Any}()
    for artifact in artifacts
        category = String(artifact["classification"])
        counts[category] = get(counts, category, 0) + 1
    end
    return Dict{String,Any}(
        "schema" => "aimora-resource-artifact-baseline-v1",
        "source_commit" => revision,
        "signature_schema" => "path-blob-classification-bytes-sha256-v1",
        "signature" => inventory_signature(artifacts),
        "artifact_count" => length(artifacts),
        "classification_count" => counts,
        "artifact" => artifacts,
    )
end

function render_inventory(data = artifact_inventory())
    output = IOBuffer()
    TOML.print(output, data; sorted = true)
    return String(take!(output))
end

function write_inventory(path::AbstractString = INVENTORY_PATH)
    open(path, "w") do io
        write(io, render_inventory())
    end
    println("Wrote individually classified baseline artifact inventory: $(path)")
    return path
end

function verify_inventory(path::AbstractString = INVENTORY_PATH)
    isfile(path) || error("baseline artifact inventory is missing: $(path)")
    expected = render_inventory()
    actual = read(path, String)
    actual == expected || error(
        "baseline artifact inventory differs from the exact source commit; " *
        "run tools/baseline_artifact_inventory.jl --write after an authorized baseline change",
    )
    println("Baseline artifact inventory matches every exact path, blob, size, and classification")
    return true
end

function main(arguments)
    if isempty(arguments) || arguments == ["--check"]
        verify_inventory()
    elseif arguments == ["--write"]
        write_inventory()
        verify_inventory()
    else
        println(stderr, "usage: julia tools/baseline_artifact_inventory.jl [--check|--write]")
        return 2
    end
    return 0
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(BaselineArtifactInventory.main(ARGS))
end
