# Classic Case 0015 — Universal Induction Machine

## Purpose

This `DCNEW-1` benchmark exercises automatic initialization of a type-4
universal induction machine followed by a 0.1 s coupled EMT horizon. It exposes
the machine's electrical, flux, torque, speed, and angle states.

## Governing equations

In a rotating \(d/q\) representation,

\[
v=Ri+\frac{d\lambda}{dt}+\omega_rJ\lambda,\qquad
\lambda=L(\theta)i,
\]

\[
T_e=\frac{\partial}{\partial\theta}
\left(\frac12 i^\mathsf{T}L(\theta)i\right),\qquad
J_m\frac{d\omega_m}{dt}=T_m-T_e-D\omega_m.
\]

The universal-machine intake defines coils, terminal coupling, parameter
basis, initialization mode, output requests, and the mechanical network.
AIMORA converts those cards into typed machine state instead of recreating
legacy global storage.

## Run and outputs

```bash
make run
```

The full 500-step deck horizon is used. The CSV/SVG expose the requested
machine and network channels; `summary.md` states the actual node/output
counts. For a steady continuation case, speed should remain close to its
initialized operating point while finite current/torque channels remain
coupled.

The exact artifacts are `classic_case0015_universal_induction_machine_timeseries.csv`, `classic_case0015_universal_induction_machine_waveforms.svg`, and `summary.md`.

Fixed-field directive normalization: [../SOURCE.md](../SOURCE.md).
