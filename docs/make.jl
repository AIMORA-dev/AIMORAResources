using Documenter

const PAGES = [
    "Home" => "index.md",
    "Professional Manual" => [
        "Manual Overview" => "professional-manual.md",
        "Getting Started" => "getting-started.md",
        "Architecture" => "architecture-reference.md",
        "Study Reference" => "study-reference.md",
        "Model Reference" => "model-reference.md",
        "Deck-Card Reference" => "deck-card-reference.md",
        "Example Catalogue" => "example-catalog.md",
        "Solver Reference" => "solver-reference.md",
        "Results and Reporting" => "results-and-reporting.md",
        "Troubleshooting" => "troubleshooting.md",
        "Source Coverage" => "source-coverage.md",
        "Glossary" => "glossary.md",
    ],
    "Engineering Topics" => [
        "Architecture Notes" => "architecture.md",
        "Studies" => "studies.md",
        "Cases and Catalogues" => "cases-and-catalogs.md",
        "Consistent EMT Initialization" => "consistent-emt-initialization.md",
        "Coupled Line Fitting and Passivity" => "coupled-line-fitting-passivity.md",
        "Coupled Frequency-Dependent Line Runtime" => "coupled-frequency-dependent-line-runtime.md",
        "Extended Semiconductor Fidelity" => "extended-semiconductor-fidelity.md",
        "Extended VSC Controls and Filters" => "extended-vsc-controls-and-filters.md",
        "General Multirate EMT Tasks" => "general-multirate-emt-tasks.md",
    ],
    "Developer Reference" => [
        "Public API" => "api.md",
        "Development" => "development.md",
    ],
]

makedocs(
    sitename = "AIMORA Documentation",
    authors = "AIMORA contributors",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://aimora-dev.github.io/AIMORAResources/",
        collapselevel = 1,
        size_threshold = 1_000_000,
    ),
    pages = PAGES,
    checkdocs = :none,
    warnonly = false,
)
