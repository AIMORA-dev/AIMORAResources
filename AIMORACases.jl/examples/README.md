# AIMORA Julia Example Gallery

Every example is a standalone Julia workflow with its own directory, README, `run.jl`, and Makefile. Examples use AIMORA's Julia production APIs only. Compiled-reference programs, private oracle data, and intentionally invalid validation fixtures are not runtime dependencies.

Input files ending in `.deck` are electrical model data, not Fortran source. They use AIMORA's readable or fixed-field input syntax and live beside the Julia `run.jl` that parses and executes them. This repository rejects Fortran source extensions during `make check`.

## Running the gallery

From the `AIMORACases.jl` repository:

```bash
make example
```

To run one example:

```bash
make -C examples/emt/rlc_energization run
```

Generated files go under that example's `outputs/` directory. Dynamic examples write a CSV time series and an SVG waveform. Static studies write CSV matrices, frequency curves, or text summaries appropriate to the calculation.

The machine-readable inclusion/exclusion inventory is [`source_coverage.toml`](source_coverage.toml); its disposition definitions and audited counts are explained in [`SOURCE_COVERAGE.md`](SOURCE_COVERAGE.md).

## Organization

- `emt/`: network transients, controls, machines, lines, nonlinear devices, restart, reporting, and performance workflows.
- `line_constants/`: overhead-line geometry and sequence-constant studies.
- `cable_constants/`: cable geometry, frequency scans, and modal results.
- `transformer_parameters/`: transformer test-data conversion and generated branch parameters.
- `support/`: dependency-free CSV, summary, and SVG helpers shared by examples.

Only study types reported by `AIMORA.StudyCatalog.implemented_studies()` receive executable study examples. Planned APIs are documented by AIMORA but are not presented here as working calculations.

## Audited inventory

The gallery contains 64 Julia-only examples in 64 named folders. Every catalogued folder owns a substantive `README.md`, `run.jl`, Makefile, and nonempty canonical `outputs/` tree. The committed result set contains 332 artifacts: 129 CSV data files, 108 SVG figures, 55 Markdown summaries, 28 text reports, 9 JSON summaries, 2 typed AIMORA checkpoints, and 1 TOML summary. No example contains a duplicate `results/` directory, workstation path, Fortran source, or compiled-reference runtime.

The source-to-example audit indexes 476 discovered records: 11 public package testsets, 82 validation suites, 76 validation fixtures, 57 canonical public case inputs consumed directly by validation, 16 classic public cases plus their shared provenance record, 11 implemented C301–C311 capability packets, 14 claimed but nonexistent C312–C325 packet designations, 93 official ATPDraw web cases, 52 bundled ATPDraw ACP projects/groups, and the claimed but unidentified DC-1–DC-63 collection. Of these records, 202 map to direct examples or explicit gallery variants; every other record has a named oracle, validation, negative-test, external-conversion, nonexistent-designation, or missing-source disposition.

The 145 ATPDraw/ACP records are privately integrity-checked source material, not redistributable public examples and not claimed as Julia conversions. The user-facing gallery contains only independently maintained Julia code and shippable electrical data. `C301` through `C311` are capability packets rather than downloadable decks; no authoritative C312–C325 or DC-1–DC-63 input collection exists in the inspected workspace. Raw licensed material, credentials, cookies, Fortran source, and compiled-reference runtimes must never enter this public repository.
