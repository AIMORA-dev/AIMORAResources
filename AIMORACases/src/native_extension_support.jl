using SHA
using UUIDs

import AIMORA.NonlinearNetwork: nonlinear_current_jacobian!,
                                   nonlinear_device_formulation,
                                   nonlinear_device_provenance,
                                   nonlinear_terminal_nodes
import AIMORA.NativeExtensions: accept_extension_state!,
                                extension_checkpoint,
                                extension_companion,
                                extension_contract,
                                extension_identity,
                                extension_outputs,
                                extension_source_value,
                                extension_terminal_nodes,
                                release_extension_task_output!,
                                restore_extension_checkpoint!,
                                sample_extension_task!

const CASES_PACKAGE_UUID = UUID("c2d99356-2241-4b88-ae11-80a94b927354")

const _PROJECT_EXTENSION_SERVICE = Dict(
    :initialize => AIMORAProject.ExtensionInitializationService,
    :nonlinear_current => AIMORAProject.ExtensionNonlinearCurrentService,
    :jacobian => AIMORAProject.ExtensionJacobianService,
    :companion_stamp => AIMORAProject.ExtensionCompanionStampService,
    :state_acceptance => AIMORAProject.ExtensionStateAcceptanceService,
    :event => AIMORAProject.ExtensionEventService,
    :sampled_task => AIMORAProject.ExtensionSampledTaskService,
    :source => AIMORAProject.ExtensionSourceService,
    :output => AIMORAProject.ExtensionOutputService,
    :checkpoint => AIMORAProject.ExtensionCheckpointService,
    :reusable_definition => AIMORAProject.ExtensionReusableDefinitionService,
)

function _public_example_identity(type_name::String, symbol::Symbol, equation::String)
    return AIMORA.NativeExtensions.ExtensionIdentity(
        CASES_PACKAGE_UUID,
        "aimora.cases.extensions",
        type_name,
        v"1.0.0",
        symbol,
        v"1.0.0",
        bytes2hex(sha256("aimora-public-extension-example-v1\n" * equation)),
    )
end

function _public_example_inventory(owned::AbstractDict{Symbol,<:Tuple})
    families = (
        :continuous,
        :algebraic,
        :discrete,
        :delayed,
        :scheduler,
        :random,
        :history,
        :output,
        :checkpoint,
    )
    return AIMORA.NativeExtensions.ExtensionStateInventory([
        haskey(owned, family) ?
        AIMORA.NativeExtensions.ExtensionStateFamily(family, owned[family]) :
        AIMORA.NativeExtensions.ExtensionStateFamily(
            family;
            not_applicable_reason = Symbol("not_applicable_", family),
        )
        for family in families
    ])
end

function _public_parameter_provenance(source::String, units::String, validity::String)
    return AIMORA.StudyCore.ParameterProvenance(
        source,
        units,
        "converted to finite Float64 SI values without inferred bases or orientation",
        "synthetic public example; roundoff and timestep error only",
        validity,
        AIMORA.StudyCore.PhysicalModelParameter,
    )
end
