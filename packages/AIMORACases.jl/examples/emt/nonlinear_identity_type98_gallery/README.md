# Nonlinear Identity and Type-98 Gallery

This Julia-only gallery demonstrates two fixed-card nonlinear ownership rules:
a `NONLIN NAME:` moniker attached to the next type-96 hysteretic inductor, and
a standalone public numeric type-98 pseudo-nonlinear inductor.

For the type-96 element, the characteristic supplies flux linkage as a
piecewise function of current,

\[
\lambda=\lambda(i),\qquad
L_{\mathrm{inc}}=\frac{d\lambda}{di},\qquad
G_{\mathrm{eq}}=\frac{\Delta t}{2L_{\mathrm{inc}}}.
\]

The moniker `HYST1` is the physical owner name carried through parsing, sparse
state, accepted current/flux, and reporting. It is not merely a display label.

The type-98 input is transformed into piecewise companion segments of the form

\[
i_k(v)=g_k v+c_k,
\]

with a live segment index and history current. The supplied table produces
finite slopes of 0.05 S and 1/220 S and exercises a segment transition. Public
type 98 is distinct from AIMORA's internal saturated-transformer bookkeeping.
Voltage is volts, current is amperes, flux linkage is webers, conductance is
siemens, and time is seconds.

## Inputs and assumptions

- `named_type96_hysteretic.deck` uses a 100 ms step and 500 ms horizon so its
  low-frequency state change is visible.
- `type98_pseudo_nonlinear.deck` uses a 10 ms step, 50 ms horizon, and 1 Hz
  source to expose the transformed characteristic.
- The coarse timesteps are educational and are not universal production
  defaults.

## Run

```bash
make run
```

## Outputs

Each variant writes `*_timeseries.csv` and `*_waveforms.svg`.
`outputs/gallery_metrics.csv` compares timing, dimensions, and peaks;
`outputs/summary.md` records the finite Julia-only execution result.

These inputs were promoted from AIMORA's C310 validation scenarios. They are
electrical deck data, not Fortran source, and need no external simulator.
