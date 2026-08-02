# Nonlinear Characteristic Gallery

This example prepares three physical curves used by nonlinear EMT devices:

- a current–flux saturation curve obtained by integrating incremental
  inductance, \(d\lambda=L_{\mathrm{inc}}(i)\,di\);
- a scaled, closed hysteresis loop with positive energy loss
  \(W=\left|\oint i\,d\lambda\right|\);
- a continuous piecewise ZnO law
  \(I=c(V/V_{\mathrm{ref}})^p\).

These are preparation calculations, not synthetic legacy-oracle data. Their
outputs feed AIMORA's saturable-inductor, hysteretic-inductor, and arrester
runtime owners.

## Units and assumptions

Current is amperes, flux linkage is webers, voltage is volts, and loop energy is joules. The incremental-inductance samples are positive and ordered by current, the normalized hysteresis template is scaled to an 8 A by 1.6 Wb closed loop, and the ZnO samples span 1 µA to 0.1 A. Each fitted power-law segment is required to join continuously. Temperature dependence, rate effects, and manufacturer tolerance bands are not modeled.

## Run

```bash
make run
```

## Outputs

- `saturation_curve.csv` and `.svg`.
- `hysteresis_loop.csv` and `.svg`.
- `zinc_oxide_fit.csv` and `.svg`.
- `summary.md`: monotonicity, loop loss, fit error, and continuity checks.

## Interpretation

The saturation curve should remain monotone while its slope decreases, representing reduced incremental inductance. The hysteresis loop must close and enclose positive loss area. On the ZnO plot, fitted and measured currents should agree within the declared relative tolerance without jumps at segment boundaries. These checks establish usable characteristics before any timestep model consumes them.
