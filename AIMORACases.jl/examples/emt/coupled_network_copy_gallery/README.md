# Coupled Network and COPY Gallery

This Julia-only gallery executes three related multiductor/line cases: an
explicit four-phase coupled R–L matrix, a copied three-phase coupled R–L
group, and a copied distributed transposed line.

For an n-phase coupled R–L group,

\[
\mathbf v(t)=\mathbf R\,\mathbf i(t)+\mathbf L\,\frac{d\mathbf i}{dt},
\]

where the fixed-card rows provide the lower triangular entries of symmetric
matrices R and L. AIMORA expands the complete matrices before forming the
trapezoidal companion

\[
\mathbf G_{\mathrm{eq}}=
\left(\mathbf R+\frac{2}{\Delta t}\mathbf L\right)^{-1}.
\]

A COPY group reuses the source owner's physical parameters but replaces its
terminal names and allocates independent current/history state. Consequently,
the copied matrices are equal while state arrays must not alias. Distributed
lines follow the same ownership rule for sequence constants and modal history.

Resistance and reactance are in ohms at fixed-card intake, inductive values are
converted to henries using the declared 60 Hz frequency, distributed-line
length is in the accepted deck unit, voltage is volts, and time is seconds.
All three cases use a 50 microsecond timestep and a 2 ms horizon.

## Inputs and assumptions

- `four_phase_coupled_rl.deck` proves that the matrix cardinality is not fixed
  to three phases.
- `coupled_rl_copy.deck` compares one explicit three-phase owner with a copied
  group on new terminals.
- `distributed_line_copy.deck` compares an original and copied distributed
  transposed line.
- The sources intentionally constrain both ends so parameter/state ownership
  can be observed without requiring a larger grid model.

## Run

```bash
make run
```

## Outputs

Each variant writes its own `*_timeseries.csv` and `*_waveforms.svg`.
`outputs/gallery_metrics.csv` compares dimensions, timestep, duration, and peak
values, while `outputs/summary.md` records the Julia-only finite-result check
and interpretation.

These cases were promoted from AIMORA's C309 validation scenarios. They require
neither ATP nor Fortran at runtime.
