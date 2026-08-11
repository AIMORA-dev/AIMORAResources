# Classic Case 0006 — 230 kV High-Frequency Line

## Purpose

This geometry case evaluates a 230 kV line at 500 kHz using the legacy
high-frequency/K.C. Lee option. It is useful for fast-front and travelling-wave
studies where power-frequency constants are inadequate.

## Governing calculation

The same matrix telegrapher form is used,

\[
\frac{\partial v}{\partial x}=-Zi,\qquad
\frac{\partial i}{\partial x}=-Yv,
\]

but \(Z(\omega)\) and \(Y(\omega)\) are evaluated at 500 kHz. The modal
propagation constant and characteristic impedance are

\[
\Gamma=(ZY)^{1/2},\qquad Z_c=Z\,\Gamma^{-1}.
\]

Skin/earth-return behavior and the physical conductor geometry therefore
change both attenuation and wave velocity relative to a 60 Hz model.

## Run and outputs

```bash
make run
```

The runner writes the line-constants report, sequence CSV, impedance SVG, and
summary. Inspect the reported frequency before comparing this result with the
60 Hz cases; a numerical difference is expected and physically meaningful.

The exact artifacts are `classic_case0006_230kv_high_frequency_line_report.txt`, `classic_case0006_230kv_high_frequency_line_sequence_constants.csv`, `classic_case0006_230kv_high_frequency_line_sequence_impedance.svg`, and `summary.md`.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
