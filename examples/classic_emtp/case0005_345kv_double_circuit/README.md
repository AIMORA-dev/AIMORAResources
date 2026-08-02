# Classic Case 0005 — 345 kV Double Circuit

## Purpose

This case shows how mutual coupling is retained for a 345 kV double-circuit
tower. Six phase groups and four shield-wire rows are placed on left and right
halves of the structure.

## Governing calculation

Each conductor pair contributes self or mutual entries to

\[
Z_{ij}(\omega)=R_{ij}+j\omega L_{ij}+Z_{\mathrm{earth},ij},
\qquad
Y(\omega)=G+j\omega C.
\]

The phase-domain matrices are symmetric for reciprocal passive geometry.
Sequence reduction is performed only after the complete coupled matrix is
assembled, so cross-circuit influence is not discarded.

The input uses feet for coordinates, inches for conductor diameters, Ω/mile
for resistance, 100 Ω·m earth resistivity, and 60 Hz.

## Run and outputs

```bash
make run
```

- a complete text report;
- `classic_case0005_345kv_double_circuit_sequence_constants.csv`;
- `classic_case0005_345kv_double_circuit_sequence_impedance.svg`;
- `summary.md`, including the physical-check result.

The sequence plot is a compact view; the report is the authoritative place to
inspect phase coupling and all units. Provenance: [../SOURCE.md](../SOURCE.md).
