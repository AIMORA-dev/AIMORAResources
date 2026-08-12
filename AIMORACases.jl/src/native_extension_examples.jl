function native_extension_registry()
    registry = AIMORA.NativeExtensions.ExtensionRegistry()
    for type in (
        PublicSampledSaturatingLag,
        PublicCubicCurrentBranch,
        PublicSeriesRLCompanion,
    )
        AIMORA.NativeExtensions.register_extension!(registry, type)
    end
    return registry
end

"""Build one callback-free project declaration for an already loaded public example type."""
function native_extension_declaration(
    type::Type,
    object_identity::AIMORAProject.ObjectIdentity,
    terminals::AbstractVector{AIMORAProject.ProjectReference},
    parameters::AbstractVector{AIMORAProject.AssetProperty},
    provenance::AIMORAProject.ProvenanceSource;
    upstream_results::AbstractVector{AIMORAProject.SemanticSchemaIdentity} =
        AIMORAProject.SemanticSchemaIdentity[],
    output_contracts::AbstractVector{AIMORAProject.SemanticSchemaIdentity} =
        AIMORAProject.SemanticSchemaIdentity[],
    reusable_definition::Union{Nothing,AIMORAProject.ProjectReference} = nothing,
)
    type in (
        PublicSampledSaturatingLag,
        PublicCubicCurrentBranch,
        PublicSeriesRLCompanion,
    ) || throw(ArgumentError("type is not an AIMORACases native extension example"))
    runtime_identity = extension_identity(type)
    contract = extension_contract(type)
    length(terminals) == contract.terminal_count || throw(ArgumentError(
        "project declaration terminal count differs from the runtime contract",
    ))
    representation = contract.representation === :instantaneous_emt ?
        AIMORAProject.InstantaneousEMT : throw(ArgumentError(
            "runtime representation has no project declaration mapping",
        ))
    fidelity = contract.fidelity === :switching_detailed ?
        AIMORAProject.SwitchingDetailed : throw(ArgumentError(
            "runtime fidelity has no project declaration mapping",
        ))
    implementation = AIMORAProject.RegisteredFunctionIdentity(
        runtime_identity.package_uuid,
        AIMORAProject.SemanticTypeId(
            AIMORAProject.NamespaceId(runtime_identity.namespace),
            AIMORAProject.ProjectId(runtime_identity.semantic_type),
            runtime_identity.semantic_version,
        ),
        AIMORAProject.ProjectId(String(runtime_identity.implementation_symbol)),
        AIMORAProject.ContentDigest(runtime_identity.content_sha256),
    )
    state = [
        isempty(family.names) ?
        AIMORAProject.ExtensionStateDeclaration(
            family.family;
            not_applicable_reason = AIMORAProject.ProjectId(
                "not_applicable.$(String(family.family))",
            ),
        ) : AIMORAProject.ExtensionStateDeclaration(
            family.family,
            [
                AIMORAProject.ProjectId("extension.$(String(name))")
                for name in family.names
            ],
        )
        for family in contract.state.families
    ]
    services = AIMORAProject.ExtensionService[
        get(_PROJECT_EXTENSION_SERVICE, service) do
            throw(ArgumentError("runtime service $service has no project declaration mapping"))
        end
        for service in contract.services
    ]
    return AIMORAProject.ExtensionDeclaration(
        object_identity,
        implementation,
        runtime_identity.api_version,
        representation,
        fidelity,
        terminals,
        parameters,
        state,
        services,
        provenance;
        upstream_results,
        output_contracts,
        reusable_definition,
    )
end
