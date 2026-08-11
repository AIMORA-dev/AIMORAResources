module ChangedResources

using TOML

export affected_resources

function resource_paths(root::AbstractString)
    index = TOML.parsefile(joinpath(root, "resource-index.toml"))
    return Dict(
        String(resource["id"]) => replace(String(resource["path"]), '\\' => '/') for
        resource in index["resource"]
    )
end

function affected_resources(root::AbstractString, changed_paths::Vector{String})
    paths = resource_paths(root)
    all_resources = sort!(collect(keys(paths)))
    affected = Set{String}()
    for raw_path in changed_paths
        path = replace(raw_path, '\\' => '/')
        matched = false
        for (resource, prefix) in paths
            if path == prefix || startswith(path, prefix * "/")
                push!(affected, resource)
                matched = true
            end
        end
        if !matched
            return all_resources
        end
    end
    return sort!(collect(affected))
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    root = normpath(joinpath(@__DIR__, ".."))
    foreach(println, affected_resources(root, ARGS))
end
