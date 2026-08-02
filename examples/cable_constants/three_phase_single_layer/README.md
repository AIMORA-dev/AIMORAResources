# Three-Phase Single-Layer Cable Constants

This original AIMORA case defines three buried single-core cables, each with a
metallic sheath and one insulation layer. The Julia cable-constants study
builds geometry, internal/earth-return impedance, electrostatic admittance,
grounded-conductor reduction, and modal quantities over frequency.

## Model, units, and assumptions

The study evaluates the per-unit-length relation \(\mathbf V'= -\mathbf Z\mathbf I\), \(\mathbf I'= -\mathbf Y\mathbf V\) using the cable geometry and material data supplied by the Julia case. Distances are metres, conductor and sheath resistivity uses SI units, frequency is hertz, series quantities are reported as impedance per unit length, and shunt quantities as admittance per unit length. The soil is homogeneous and the conductors are longitudinally uniform; terminations and a finite cable length are intentionally outside this parameter study.

## Run

```bash
make run
```

## Outputs

- `cable_constants_report.txt`: full conductor, matrix, and modal report.
- `cable_frequency_scan.csv`: mode-1 characteristic impedance and velocity.
- `series_impedance_60hz.csv`: complex reduced series-impedance matrix.
- `cable_characteristic_impedance.svg`: frequency response.

The scan is logarithmic from 60 Hz upward. Characteristic impedance and modal
velocity should remain finite, while every generated frequency state must pass
symmetry, passivity, and modal residual checks.

## Interpretation

Compare the three phase-domain diagonal terms to confirm geometric balance, then inspect the mode-1 frequency curve for the expected smooth skin- and earth-return trend. A negative passivity margin, discontinuous modal curve, or large symmetry residual indicates inconsistent geometry/material data rather than a usable cable model.
