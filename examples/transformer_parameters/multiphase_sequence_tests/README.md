# Multiphase Transformer Sequence Tests

This typed BCTRAN-style example converts positive- and zero-sequence
short-circuit test data into a full three-phase terminal representation.

## Model, units, and assumptions

Two three-phase windings are rated 230 kV and 69 kV on a 150 MVA test base. The input separates positive- and zero-sequence pair loss and short-circuit impedance at 60 Hz, then applies the sequence-to-phase transformation to construct terminal \(\mathbf R\) and \(\mathbf X\) in ohms. Phase ordering is consistent on both windings, matrices are reciprocal/symmetric, and the conversion represents linear leakage behavior; phase shift, taps, saturation, frequency dependence, and a time-domain energization are outside this example.

## Run

```bash
make run
```

## Outputs

- `resistance_matrix_ohm.csv` and `reactance_matrix_ohm.csv`: full terminal matrices.
- `terminal_self_reactance.svg`: terminal self-reactance comparison.
- `summary.md`: reconstruction, symmetry, and physical checks.

Positive- and zero-sequence inputs are reconstructed independently before
being transformed to phase terminals. Small reconstruction residuals show that
the generated matrix preserves the supplied tests.

## Interpretation

Compare diagonal entries to see terminal self-reactance and off-diagonal entries to see coupling imposed by the sequence transformation. The summary residuals must be small for both sequence tests and symmetry. A good residual proves faithful conversion of the supplied test data, not that those illustrative ratings describe a particular manufactured transformer.
