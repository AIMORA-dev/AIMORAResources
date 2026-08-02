# Hysteretic Inductor Runtime

This Julia-only case drives a type-96 hysteretic inductor through AIMORA's
primary sparse-network timestep loop. The characteristic table gives flux
linkage \(\lambda\) as a function of current:

\[
\lambda(i)=
\begin{cases}
2i, & 0\le i\le 2\ \mathrm A,\\
\text{piecewise continuation with hysteretic state}, & \text{otherwise}.
\end{cases}
\]

The companion conductance uses the local slope
\[
L_{\mathrm{inc}}=\frac{d\lambda}{di},
\qquad
G_{\mathrm{eq}}=\frac{\Delta t}{2L_{\mathrm{inc}}},
\]
while the history current carries the preceding branch state. The internal
direction flag determines whether the ascending or descending path is active;
this makes the element stateful even when two samples have the same voltage.

The source is 0.1 peak V at 1 Hz with a 100 ms timestep and a 500 ms horizon.
Those coarse values make the state change obvious and are not a recommended
production timestep.

## Run

```bash
make run
```

## Results

- `hysteretic_inductor_runtime_timeseries.csv`: node voltage and requested
  branch/output channels.
- `hysteretic_inductor_runtime_waveforms.svg`: finite nonlinear response.
- `summary.md`: timestep, sample count, channels, and peak value.

Use `nonlinear_characteristic_gallery` to inspect prepared saturation,
hysteresis, and zinc-oxide curves without a network solve.
