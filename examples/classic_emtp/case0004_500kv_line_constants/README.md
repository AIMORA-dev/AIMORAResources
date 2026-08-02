# Classic Case 0004 — 500 kV Line Constants

## Purpose

This static study converts the physical geometry of a flat 500 kV line with
bundled phase conductors and two shield wires into phase and sequence line
constants at 60 Hz.

## Governing calculation

For angular frequency \(\omega\), AIMORA builds the complex series impedance
and shunt admittance matrices,

\[
Z(\omega)=R_{\mathrm{internal}}+Z_{\mathrm{earth}}+
j\omega L_{\mathrm{external}},\qquad
Y(\omega)=G+j\omega C.
\]

Carson earth-return corrections use the 100 Ω·m soil resistivity from the
frequency card. Electrostatic potential coefficients produce \(C\). The modal
or sequence quantities follow from the matrix eigen/sequence transformation;
for one uncoupled mode,

\[
Z_c=\sqrt{\frac{Z}{Y}},\qquad \gamma=\sqrt{ZY}.
\]

Conductor diameter is entered in inches and horizontal/vertical geometry in
feet; the Julia owner converts them to SI internally and reports the requested
legacy per-mile quantities.

## Run and outputs

```bash
make run
```

- `outputs/classic_case0004_500kv_line_constants_report.txt`
- `outputs/classic_case0004_500kv_line_constants_sequence_constants.csv`
- `outputs/classic_case0004_500kv_line_constants_sequence_impedance.svg`
- `outputs/summary.md`

Check that the physical passivity/symmetry flag is true and compare the zero-
and positive-sequence surge impedances. No artificial sine waveform is made
for a static geometry calculation.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
