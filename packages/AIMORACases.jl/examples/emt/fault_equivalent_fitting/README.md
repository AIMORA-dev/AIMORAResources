# Fault Generator-Equivalent Fitting

This static preparation example fits one passive generator equivalent per
sequence-network node. For network admittance \(Y_n\) and diagonal generator
admittance \(Y_g\), AIMORA solves

\[
\operatorname{diag}\!\left[(Y_n+Y_g)^{-1}\right]=X_{\mathrm{target}}.
\]

The resulting reactance and user-supplied X/R ratio define passive R–L
generator branches that can initialize an EMT fault study.

## Model, units, and assumptions

The example uses a 60 Hz passive sequence network. Reactances and fitted residuals are in ohms, the supplied X/R ratio determines resistance through \(R=X/(X/R)\), and the corresponding inductance is \(L=X/(2\pi f)\). The target diagonal driving-point reactances are assumed positive and compatible with the selected network topology; this preparation step does not apply a fault or integrate an EMT waveform.

## Run

```bash
make run
```

## Outputs

- `fault_equivalent_fit.csv`: targets, reconstructed values, residuals, R and X.
- `fault_equivalent_fit.svg`: target versus reconstructed reactance.
- `network_admittance.csv`: reciprocal sequence-network matrix.
- `summary.md`: convergence, passivity, and maximum residual.

## Interpretation

The reconstructed and target points should overlap in the plot, and the maximum residual should be small relative to the targets. Positive fitted R and L establish passive branches. A failed convergence or negative fitted parameter signals that the requested driving-point targets cannot be represented by this chosen diagonal generator-equivalent structure.
