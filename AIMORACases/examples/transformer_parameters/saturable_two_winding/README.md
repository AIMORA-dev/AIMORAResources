# Saturable Two-Winding Transformer Parameters

This example uses typed winding and magnetizing data to generate the linear
branch matrices that support a saturable transformer model.

## Model, units, and assumptions

The two windings are rated 132 kV and 33 kV at 60 Hz with declared winding resistance and leakage data. AIMORA separates equivalent series leakage from the parallel magnetizing branch, using \(L=X/(2\pi f)\), and returns resistance in ohms and physical inductance in henries. The generated matrices are linear, reciprocal, and referred according to the winding ratings. The scalar magnetizing specification establishes a linear operating branch; the nonlinear flux-current characteristic, hysteresis, remanence, core loss variation, and winding capacitance must be supplied by a later EMT model.

## Run

```bash
make run
```

## Outputs

- `branch_resistance_matrix_ohm.csv`: branch resistance matrix.
- `physical_inductance_matrix_h.csv`: physical inductance matrix.
- `winding_inductance.svg`: winding self-inductance comparison.
- `summary.md`: magnetizing and equivalent series parameters.

The example is a parameter-conversion study, not an inrush simulation. Use the
generated matrices as model inputs, then combine them with a nonlinear
magnetizing characteristic in an EMT case.

## Interpretation

The plotted self-inductances should be positive and scale consistently with winding bases, while the matrices should be symmetric and physically admissible. The summary separates magnetizing and equivalent series quantities so users can map each to the correct runtime branch. Passing checks validates this conversion contract; it does not produce an energization waveform.
