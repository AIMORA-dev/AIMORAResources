# Documentation Source Coverage

The documentation gate maps public source owners and executable resources to one canonical documentation location. It prevents attractive high-level pages from hiding undocumented models, cards, studies, cases, results, or failure behavior.

## Coverage rules

### Public engine

The gate inventories:

- `AIMORA.jl/src/models/**/*.jl`;
- `AIMORA.jl/src/studies/**/*.jl`;
- `AIMORA.jl/src/io/deck_parser/**/*.jl`;
- `AIMORA.jl/src/solver_api/**/*.jl`;
- exported public names from the package entry point.

Every discovered family must be classified as:

- documented public model/API;
- internal implementation detail covered by its public owner page;
- planned contract documented as unavailable;
- compatibility/legacy owner with an explicit boundary.

### Platform packages

The gate inventories project, formats, layout, service, visuals, reporting, and symbols. Reporting source must be covered by [Results and reporting](results-and-reporting.md); it may not be described as implemented when the package is only a scaffold.

### Public cases

For every row in `AIMORACases.jl/examples/catalog.toml`, the gate requires:

- unique case ID;
- existing entry point;
- existing primary input or explicitly entrypoint-only case;
- substantive README beside the case;
- nonempty canonical output directory for released examples;
- study-family and solver-requirement declarations;
- result kind;
- provenance/source IDs;
- no prohibited absolute path, credential, private oracle, or compiled runtime.

The case README is the canonical detailed case documentation; [Example catalogue](example-catalog.md) is the cross-case index and workflow guide.

### Report templates

Every released template requires:

- manifest row;
- stable ID and semantic version;
- licence and trust class;
- family and supported studies;
- required section roles;
- output profiles;
- no executable code or hidden engineering semantics;
- example/report compatibility evidence.

## Required manual pages

The following pages are mandatory:

```text
professional-manual.md
architecture-reference.md
study-reference.md
model-reference.md
deck-card-reference.md
example-catalog.md
solver-reference.md
results-and-reporting.md
troubleshooting.md
source-coverage.md
glossary.md
```

## Claims audit

Documentation must not claim that a planned study is executable. The checker reads the public study catalogue and compares implemented IDs against wording in the manual. Case-specific EMT phenomena do not automatically become general study APIs.

## Link and path audit

Local Markdown links must resolve under `docs/src`. Repository-relative links must point to tracked public content. Absolute workstation paths, temporary sandbox paths, private repository URLs, credentials, and tokenized download URLs are rejected.

## Reproducible check

From the `AIMORAResources` checkout:

```bash
julia --startup-file=no docs/check_content.jl
make -C docs build
```

The check reports counts for manual pages, catalogue rows, documented case READMEs, templates, broken links, and uncovered public owners. Counts are evidence only when the gate passes at an exact revision.

## Updating coverage

When adding a public model, card family, study, result, renderer, template, or case:

1. update the canonical source owner;
2. add or update its public API/model documentation;
3. add or update a public example where legally possible;
4. add limitations and failure behavior;
5. update the coverage inventory/check when a new owner class is introduced;
6. run the documentation and package gates before publication.
