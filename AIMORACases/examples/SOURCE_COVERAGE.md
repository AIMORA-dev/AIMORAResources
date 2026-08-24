# Source Coverage Audit

`source_coverage.toml` is the machine-readable inclusion and exclusion index for material inspected while building this Julia-only gallery. It records a source once even when several source scenarios are consolidated into one teaching gallery. It does not count examples, and it does not claim that a private ATPDraw project has been converted merely because its source is indexed.

## Audited snapshot

The 2026-08-24 snapshot contains 518 source records:

| Source kind | Records | Current disposition |
| --- | ---: | --- |
| AIMORA public reference formulations | 11 | 11 example/gallery |
| AIMORA public package testsets | 11 | 7 example/gallery, 4 validation-only |
| AIMORAValidation registered comparison commands | 3 | 3 example |
| AIMORAValidation suite files | 89 | 80 example/gallery, 3 oracle-only, 6 validation-only |
| AIMORAValidation fixtures | 76 | 38 example/gallery, 27 oracle-only, 8 derived comparison controls, 3 negative tests |
| Canonical case inputs consumed by validation | 78 | 78 example/gallery; no duplicate validation fixture |
| Classic public EMTP cases | 16 | 16 direct examples |
| Shared classic-case provenance record | 1 | gallery provenance for all 16 cases |
| Implemented C301–C311 capability packets | 11 | 10 galleries, 1 validation-only |
| Claimed C312–C325 designations | 14 | not decks; no authoritative source exists |
| Official ATPDraw web cases | 93 | privately archived, pending export and conversion |
| ATPDraw 7.3 bundled ACP projects/groups | 52 | privately archived, pending export and conversion |
| Claimed DC-1–DC-63 collection | 63 | source missing |

Across all kinds, 102 records map directly to an example, 142 map to a consolidated gallery, 30 are reference-output/oracle material, 19 are validation-only or derived-comparison contracts, 3 are intentionally invalid negative tests, 14 are nonexistent packet designations, 145 await ACP export and independent Julia implementation, and 63 lack an identifiable source.

## Disposition rules

- `example`: the source scenario has a direct runnable Julia example.
- `gallery`: its shippable behavior is an explicit variant in one or more runnable examples.
- `oracle_only`: expected output or compiled-reference harness used only for qualification; it is not a user study.
- `validation_only`: repository, rejection, or evidence-integrity behavior that is unsuitable as a scientific example.
- `negative_test`: intentionally invalid input retained to prove rejection.
- `pending_export`: an ACP source is inventoried privately, but conversion is not claimed until an ATP text export is understood and independently implemented with AIMORA.
- `source_missing`: a requested designation has no authoritative file or index in the inspected material.
- `not_a_deck`: the claimed designation is absent and is not an executable case in the authoritative translation record.

## Integrity contract

`julia --project=. check.jl` verifies the schema, source count, aggregate counts, unique source IDs, disposition constraints, catalog back-references, local case paths, official ATPDraw URLs, and archive-member notation. In the full AIMORA workspace, registered comparison-command paths are checked and the validation inventory is additionally compared with the canonical `AIMORAValidation/tests/suite` and `tests/fixtures` trees before publication.

Licensed ACP files, credentials, cookies, compiled programs, and private oracle output are intentionally absent from this public repository. A public example contains only independently maintained Julia code, redistributable input data, explanation, and reproducible result artifacts.
