# Documentation Source Coverage

The current documentation gate verifies the public manual, registered cases, report templates, local links, public/private path boundary, and a loadable public engine input. It does not by itself prove exhaustive source-symbol-to-documentation coverage; that broader comparison remains a release-review responsibility until a generated source inventory is accepted.

## Coverage rules

### Public engine

Documentation review is organized around:

- `AIMORA.jl/src/models/**/*.jl`;
- `AIMORA.jl/src/studies/**/*.jl`;
- `AIMORA.jl/src/io/deck_parser/**/*.jl`;
- `AIMORA.jl/src/solver_api/**/*.jl`;
- exported public names from the package entry point.

Every family claimed by the manual must be classified as:

- documented public model/API;
- internal implementation detail covered by its public owner page;
- planned contract documented as unavailable;
- compatibility/legacy owner with an explicit boundary.

### Platform packages

The manual covers project, formats, layout, service, visuals, reporting, and symbols at their public boundary. Reporting source is covered by [Results and reporting](results-and-reporting.md); it may not be described as implemented when the package is only a scaffold.

### Public cases

For every row in `AIMORACases.jl/examples/catalog.toml`, the gate requires:

- unique case ID;
- existing entry point;
- existing primary input or explicitly entrypoint-only case;
- substantive README beside the case;
- nonempty canonical output directory for released examples;
- study-family and solver-requirement declarations;
- result kind;
- provenance/source IDs for newly released cases; existing omissions are reported explicitly as warnings until corrected with real provenance;
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

Documentation must not claim that a planned study is executable. The study reference labels planned IDs, and release review compares those labels with the public study catalogue. The current lightweight content checker does not claim semantic proof of every status sentence. Case-specific EMT phenomena do not automatically become general study APIs.

## Link and path audit

Local Markdown links must resolve under `docs/src`. Repository-relative links must point to tracked public content. Absolute workstation paths, temporary sandbox paths, private repository URLs, credentials, and tokenized download URLs are rejected.

## Reproducible check

From the `AIMORAResources` checkout:

```bash
julia --startup-file=no docs/check_content.jl
make -C docs build
```

The check reports counts for manual pages, catalogue rows, case READMEs, templates, missing provenance warnings, and broken links. Counts are evidence only for those checked boundaries at an exact revision.

## Updating coverage

When adding a public model, card family, study, result, renderer, template, or case:

1. update the canonical source owner;
2. add or update its public API/model documentation;
3. add or update a public example where legally possible;
4. add limitations and failure behavior;
5. update the coverage inventory/check when a new owner class is introduced;
6. run the documentation and package gates before publication.
