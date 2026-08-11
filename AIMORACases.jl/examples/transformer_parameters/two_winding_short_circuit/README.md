# Two-Winding Short-Circuit Conversion

This typed Julia example converts nameplate/test data into a passive two-winding
transformer impedance/admittance representation and generated branch rows.

## Run

```bash
make run
```

## Inputs

- 132/33 kV winding ratings.
- 420 kW pair loss.
- 10.5% short-circuit impedance on 100 MVA.
- 0.8% magnetizing current.

## Model, units, and assumptions

The pair test is converted on its 100 MVA base: copper loss determines the resistive component, 10.5% short-circuit impedance determines the magnitude, and \(X=\sqrt{|Z|^2-R^2}\) supplies the leakage reactance. Rated voltages are kV, pair loss is kW, rating is MVA, generated impedance is ohms, and admittance is siemens. The representation is linear, reciprocal, passive, and referred to the declared winding terminals; taps, phase shift, frequency dependence, saturation, and detailed no-load loss are omitted.

## Outputs

- `impedance_matrix_ohm.csv` and `admittance_matrix_s.csv`: complex impedance and admittance matrices.
- `winding_impedance.svg`: winding self R/X comparison.
- `summary.md`: residual and physical checks.

The admittance/impedance inverse residual and symmetry residual should be near
machine precision.

## Interpretation

The R/X SVG makes the relative copper-loss and leakage-reactance contributions visible on each winding base. The CSV matrices are the reusable numerical result. Confirm positive diagonal resistance/reactance, symmetry, and a small \(\|\mathbf Y\mathbf Z-\mathbf I\|\) residual before using them. These checks show internal consistency with the supplied nameplate tests, not independent manufacturer validation.
