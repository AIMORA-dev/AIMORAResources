# AIMORAResources

AIMORAResources is the consolidated public repository for AIMORA cases, catalogues, independent reference models, the historical BPA EMTP reference, report templates, documentation, teaching routes, examples, and provenance. Public content remains separated from private held-out evidence and can be released as one coherent Resources revision.

| Path | Resource | Stable identity |
| --- | --- | --- |
| `packages/AIMORACases.jl` | Public executable cases | `c2d99356-2241-4b88-ae11-80a94b927354` |
| `packages/AIMORACatalogs.jl` | Study-aware equipment catalogues | `2b6c9f6e-dc5c-4462-b175-cd3ce62f4f80` |
| `packages/AIMORAReferenceModels.jl` | Independent analytical/manufactured checks | `6a268073-c1b2-474c-bd10-49e12d1609a5` |
| `references/bpa_emtp` | Historical compiled BPA EMTP reference | `379ef2ed-aa07-4523-9a5b-6fc193417d96` |
| `report-templates` | Research, commercial, and education report templates | content library |
| `docs` | Public AIMORA documentation site | Documenter project |

Run `julia test/runtests.jl` for the repository, licence, provenance, and artifact-policy contract. Run each Julia package's normal `Pkg.test()` command for package-local behavior; the BPA reference retains its own optional compiler-backed build and test commands, and documentation retains its own build command.

The first Resources integration commit has the six exact source revisions as parents, so the original commits, authors, dates, and messages remain reachable without rewritten SHAs. `provenance/history-map.toml` records the migration boundary, while the old repositories remain available until final migration acceptance.

See `licensing.toml` before redistributing any path. The repository licence does not replace the historical BPA notices or any path-specific third-party terms. Private cases, held-out evidence, restricted data, proprietary simulator artifacts, and qualification receipts remain in `AIMORAValidation` and must never enter this repository.
