using Documenter

const REPOSITORY_ROOT = @__DIR__
const AIMORA_PATH = let
    configured = strip(get(ENV, "AIMORA_DOCS_ENGINE_PATH", ""))
    workspace_candidate = normpath(joinpath(REPOSITORY_ROOT, "..", "..", "AIMORA.jl"))
    if !isempty(configured)
        abspath(configured)
    elseif isfile(joinpath(workspace_candidate, "src", "AIMORA.jl"))
        workspace_candidate
    else
        ""
    end
end

!isempty(AIMORA_PATH) && isfile(joinpath(AIMORA_PATH, "src", "AIMORA.jl")) ||
    error("Place AIMORA.jl beside this checkout or set AIMORA_DOCS_ENGINE_PATH")

pushfirst!(LOAD_PATH, AIMORA_PATH)
using AIMORA

const PAGES = [
    "Home" => "index.md",
    "Professional Manual" => [
        "Manual Overview" => "professional-manual.md",
        "Getting Started" => "getting-started.md",
        "Professional Workflow" => "professional-workflow.md",
        "Architecture" => "architecture-reference.md",
        "Study Reference" => "study-reference.md",
        "Model Reference" => "model-reference.md",
        "Deck-Card Reference" => "deck-card-reference.md",
        "Example Catalogue" => "example-catalog.md",
        "Solver Reference" => "solver-reference.md",
        "Results and Reporting" => "results-and-reporting.md",
        "Results and Validation" => "results-and-validation.md",
        "Troubleshooting" => "troubleshooting.md",
        "Source Coverage" => "source-coverage.md",
        "Glossary" => "glossary.md",
    ],
    "Engineering Topics" => [
        "Architecture Notes" => "architecture.md",
        "Studies" => "studies.md",
        "Cases and Catalogues" => "cases-and-catalogs.md",
        "Consistent EMT Initialization" => "consistent-emt-initialization.md",
        "Nonlinear EMT" => "nonlinear-emt.md",
        "Extended Semiconductor Fidelity" => "extended-semiconductor-fidelity.md",
        "Generic Bridge Topologies" => "generic-bridge-topologies.md",
        "Extended Converter Systems" => "extended-converter-systems.md",
        "Extended VSC Controls and Filters" => "extended-vsc-controls-and-filters.md",
        "General Multirate EMT Tasks" => "general-multirate-emt-tasks.md",
        "Portable EMT Snapshots" => "portable-emt-snapshots.md",
        "Local Multirate and Partitioned EMT" => "local-multirate-partitioned-emt.md",
        "Optional DASSL-Class Variable-Step EMT" => "dassl-class-variable-step-emt.md",
        "Performance Execution" => "performance-execution.md",
        "Real-Time and HIL Interfaces" => "realtime-hil-interfaces.md",
        "Wideband Line Parameters" => "wideband-line-parameters.md",
        "Coupled Line Fitting and Passivity" => "coupled-line-fitting-passivity.md",
        "Coupled Frequency-Dependent Line Runtime" => "coupled-frequency-dependent-line-runtime.md",
        "Transformer and Reactor Hierarchy" => "transformer-reactor-hierarchy.md",
        "Modern EMT Machine Families" => "modern-emt-machine-families.md",
        "EMT Instruments and Measurement Chains" => "emt-measurement-chains.md",
        "EMT Protection and Breaker Logic" => "emt-protection-breaker.md",
        "Surge and Insulation Platform" => "surge-insulation-platform.md",
        "Native Extensions" => "native-extensions.md",
        "Validation" => "validation.md",
    ],
    "Developer Reference" => [
        "Public API" => "api.md",
        "Development" => "development.md",
    ],
    "Generated Public Inventories" => [
        "Study Catalogue" => "generated/study-catalog.md",
        "Model Declaration Index" => "generated/model-index.md",
        "Deck and Card Declaration Index" => "generated/deck-card-index.md",
        "Case Catalogue" => "generated/case-catalog.md",
    ],
]

makedocs(
    sitename = "AIMORA",
    modules = [AIMORA],
    repo = Documenter.Remotes.GitHub("AIMORA-dev", "AIMORAResources"),
    remotes = Dict(
        AIMORA_PATH => Documenter.Remotes.GitHub("AIMORA-dev", "AIMORA.jl"),
    ),
    format = Documenter.HTML(
        canonical = "https://aimora-dev.github.io/AIMORAResources/",
        edit_link = "main",
        inventory_version = "0.1.0",
        prettyurls = get(ENV, "CI", "false") == "true",
        size_threshold = 1_000_000,
    ),
    pages = PAGES,
    checkdocs = :none,
    warnonly = [:cross_references, :missing_docs],
)
