# Results and Reporting

AIMORA results are typed engineering data bound to exact project, scenario, study, solver, schema, unit-base, assumption, warning, and upstream-result identities. A report is a semantic document built from those immutable results. It is not a screenshot, console transcript, mutable spreadsheet, or template that recomputes the study.

## Result identity

Every reusable result records:

- project ID and revision;
- scenario ID;
- study ID and family;
- representation and fidelity;
- settings and tolerances;
- solver/package revision;
- result schema version;
- units and bases;
- assumptions and validity domain;
- warnings and readiness state;
- upstream result hashes;
- payload SHA-256.

A report binds one or more result identities. Changing a bound result changes the report content hash and invalidates prior approval.

## Semantic report structure

`AIMORAReporting.jl` provides renderer-independent blocks:

- narrative and findings;
- equations and symbol definitions;
- typed key-value summaries;
- typed numerical tables;
- plots with axis/unit/series/event/uncertainty semantics;
- figures with captions and accessibility text;
- diagnostics and evidence references;
- document-control metadata;
- review comments and approval records.

Every section and block has a stable component ID. Review comments therefore remain attached when sections are reordered.

## Study providers

The current public provider registry covers:

- EMT;
- overhead-line constants;
- cable constants;
- transformer-parameter conversion;
- validation/qualification summaries;
- combined cross-study reports.

Each provider declares a minimum useful set of section roles. A released study without a provider or a provider missing mandatory content fails instead of producing an incomplete report.

## EMT results

A complete EMT result may contain:

- time vector and sample schedule;
- node voltages and branch currents;
- power and energy channels;
- switch/breaker/event trace;
- control and sampled-task trace;
- machine electrical/mechanical quantities;
- line/cable history or admitted diagnostic products;
- measurement/instrument channels;
- convergence, KCL, energy, passivity, initialization, and restart diagnostics;
- checkpoint state and schema identity.

### EMT interpretation checklist

1. Confirm timestep, duration, output sampling, and event times.
2. Confirm units, polarity, phase, terminal orientation, and per-unit bases.
3. Examine initial-condition residual or accepted startup transient.
4. Inspect switching/event localization; do not infer exact peaks from a coarsely sampled plot.
5. Review KCL and energy residuals over the full horizon and around discontinuities.
6. Compare timestep refinement where the claim depends on peak or timing accuracy.
7. Confirm event-preserving figure sampling.
8. For restart claims, compare uninterrupted and split-run bytes or declared tolerances.

## Line- and cable-constants results

Report:

- primitive and reduced Z/Y matrices;
- sequence and modal quantities where admitted;
- conductor ordering and transformation convention;
- frequency grid and units;
- earth/material assumptions;
- characteristic impedance and propagation quantities;
- conditioning, reciprocity/symmetry, passivity, and fit diagnostics;
- geometry/construction summary;
- validity and extrapolation limits.

A sequence value without conductor/phase mapping and base convention is incomplete.

## Transformer-parameter results

Report:

- winding ratings/order/connections;
- test-data bases and temperatures;
- conversion assumptions;
- leakage and magnetizing parameters;
- generated branch/coupling matrices;
- residuals between supplied and reconstructed tests;
- uncertainty and non-identifiable quantities;
- intended model tier and validity domain.

## Table semantics

A report table stores numerical values and declared column types separately from display formatting. Each column may declare a unit. CSV and JSON companions therefore remain machine usable.

QA checks include:

- column/type/unit length;
- row shape;
- declared-type compatibility;
- finite numerical values;
- empty tables;
- source/result references;
- preservation of the original typed value.

## Figure semantics

A plot declares:

- x and y axes, units, and linear/log scale;
- one or more typed series;
- source-result hash;
- event indices;
- uncertainty bounds;
- transformations/downsampling;
- clipping;
- caption and alternative description;
- deterministic style key.

### Event-preserving downsampling

When a long waveform is reduced for publication, AIMORA preserves:

- first and last samples;
- declared event samples;
- samples adjacent to events;
- local minima and maxima in deterministic buckets.

If the mandatory event set exceeds the target sample budget, the mandatory set wins. A renderer never drops a switching peak merely to satisfy a cosmetic point count.

## Semantic QA

Blocking QA includes:

- missing immutable result binding;
- invalid SHA-256 identities;
- duplicate component IDs;
- missing required section roles;
- malformed table shapes/types;
- NaN/Inf;
- non-monotonic coordinates;
- invalid logarithmic domains;
- invalid event indices;
- incomplete or non-enclosing uncertainty;
- missing caption or alternative description;
- unknown dependency nodes/parents;
- dependency cycles;
- unresolved blocking review comments;
- approval not bound to current content;
- mutation after publication freeze.

Warnings include empty optional content, missing noncritical display units, declared clipping, and duplicate visual styles. A publication manifest retains unresolved warnings.

## Rendered formats

One semantic report can be rendered without rerunning the study to:

- Markdown;
- sanitized accessible HTML;
- plain text;
- canonical JSON;
- portable TeX;
- PDF through an explicitly available locked Tectonic profile;
- CSV numerical companions;
- SVG vector figures;
- TikZ figure source;
- TOML publication manifest.

Missing TeX tooling produces a typed diagnostic. Portable TeX, data, and other formats remain available.

## Review and publication lifecycle

```text
Draft → Review → Approved → Frozen → Superseded/Withdrawn
```

- A draft must pass semantic QA before review.
- Review comments attach to stable component IDs.
- Blocking comments must be resolved before approval.
- Approval records actor, role, action time, and exact report content hash.
- Freeze verifies current approval and records the immutable content hash.
- A correction is a new revision with `supersedes`; the prior frozen report is marked `superseded_by`.
- Silent overwrite of a frozen publication is prohibited.

## Publication bundle

A standard output directory may contain:

```text
report.md
report.html
report.txt
report.json
report.tex
data/*.csv
figures/*.svg
tikz/*.tex
manifest.toml
```

The manifest records report ID/revision/hash, template hash, deterministic source date, warnings, artifact paths, and SHA-256 checksums. Generated-file cleanup removes only stale paths listed in a prior manifest. Unmanifested authored files are preserved.

## Versioned templates

Templates declare structure, required section roles, supported studies, output profiles, licence, and trust class. Templates do not own engineering equations, transforms, results, or compliance decisions. Publisher/standard/client branding is not claimed without exact rights and compatibility evidence.

## Complete example

From `AIMORAPlatform/AIMORAReporting`:

```bash
make example
```

The example builds a manufactured, explicitly bounded result fixture; binds it; creates table/figure content; runs QA; records and resolves a review comment; approves and freezes the report; and writes deterministic portable outputs. The fixture demonstrates reporting behavior and is not a new solver-qualification claim.
