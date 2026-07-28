module AIMORACases

using TOML

export CaseDescriptor, available_cases, case_descriptor, case_path

struct CaseDescriptor
    id::Symbol
    study::Symbol
    path::String
    description::String
    requires_solver::Bool
    reference_compatible::Bool
end

package_root() = normpath(joinpath(@__DIR__, ".."))

function available_cases()
    catalog = TOML.parsefile(joinpath(package_root(), "cases", "catalog.toml"))
    descriptors = CaseDescriptor[]
    for row in catalog["case"]
        descriptor = CaseDescriptor(
            Symbol(row["id"]),
            Symbol(row["study"]),
            String(row["path"]),
            String(row["description"]),
            Bool(row["requires_solver"]),
            Bool(row["reference_compatible"]),
        )
        isfile(joinpath(package_root(), descriptor.path)) ||
            error("Case catalog path does not exist: $(descriptor.path)")
        push!(descriptors, descriptor)
    end
    sort!(descriptors; by = descriptor -> String(descriptor.id))
    return descriptors
end

function case_descriptor(id::Symbol)
    descriptor = findfirst(case -> case.id == id, available_cases())
    descriptor === nothing && throw(KeyError(id))
    return available_cases()[descriptor]
end

case_path(id::Symbol) = joinpath(package_root(), case_descriptor(id).path)

end
