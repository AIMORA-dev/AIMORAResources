# Complete Semantic Reporting Example

This public example documents the reporting lifecycle implemented by `AIMORAPlatform/AIMORAReporting`. It uses a deterministic manufactured result fixture so the example can exercise result binding, tables, figures, QA, review, approval, freeze, and rendering without becoming a new numerical-solver claim.

## Purpose

The example demonstrates:

1. immutable project/scenario/study/result binding;
2. canonical SHA-256 payload and report hashes;
3. a minimum EMT semantic report provider;
4. typed numerical tables;
5. a figure with units, source hash, event index, caption, and accessibility text;
6. semantic and visual QA;
7. stable review comments and resolution;
8. approval bound to the current content hash;
9. publication freeze;
10. deterministic Markdown, HTML, text, JSON, TeX, CSV, SVG, TikZ, and manifest output.

## Run

From `AIMORAPlatform/AIMORAReporting`:

```bash
make example
```

or:

```bash
julia --startup-file=no --project=. examples/complete_report/run.jl outputs
```

## Expected products

```text
outputs/
  report.md
  report.html
  report.txt
  report.json
  report.tex
  data/key-results.csv
  figures/capacitor-voltage-waveform.svg
  tikz/capacitor-voltage-waveform.tex
  manifest.toml
```

The manifest must contain the same artifact checksums when the example is rebuilt from the same revision with the same declared source date.

## Claim boundary

The waveform is manufactured solely to validate reporting behavior. It does not qualify the EMT solver, a physical RLC case, a standard, or a commercial report profile. Numerical claims require separately accepted qualification evidence.
