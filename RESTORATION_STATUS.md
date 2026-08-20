# Documentation and reporting resources restoration status

Branch: `agent/restore-documentation-reporting`

This branch restores the professional AIMORA documentation corpus, report-template library, and public reporting example to the writable personal fork. It is intended as the source branch for a later pull request to `AIMORA-dev/AIMORAResources`.

## Restored documentation

The Documenter manual now includes:

- professional manual entry point;
- repository and execution architecture;
- complete public model-family reference;
- exhaustive implemented/planned study catalogue;
- deck-card family reference;
- public example catalogue and per-case documentation contract;
- production solver public boundary and diagnostics;
- typed results, semantic reporting, QA, review, freeze, and publication guidance;
- engineering troubleshooting;
- source-to-documentation coverage rules;
- engineering glossary.

Per-case `README.md` files beside each registered `run.jl` remain the canonical detailed documentation for every example. The manual provides the cross-case index, workflow, output interpretation, and coverage contract without duplicating case content.

## Restored reporting resources

`report-templates/v1/` contains a versioned manifest and profiles for:

- general engineering reports;
- reproducible research reports;
- qualification reports;
- education/laboratory reports;
- EMT studies;
- line and cable constants;
- transformer-parameter conversion;
- combined cross-study reports.

`examples/reporting/complete_report/` documents the public reporting fixture and its claim boundary.

## Verification

The branch contains `.github/workflows/restore-documentation-verification.yml`. It runs the documentation/case/template coverage checker, builds the Documenter site under Julia 1.10, validates every template using the restored `AIMORAReporting.jl` contract, and runs `git diff --check`. A successful run writes `docs/RESTORE_VERIFICATION.md`.

This restoration does not claim organization-level acceptance, scientific qualification, or ledger promotion. Those occur only after upstream review and the AIMORA workspace qualification process.

## Upstream pull request

Target repository: `AIMORA-dev/AIMORAResources`

Target branch: `main`

Head repository: `ahmelkholy/AIMORAResources`

Head branch: `agent/restore-documentation-reporting`
