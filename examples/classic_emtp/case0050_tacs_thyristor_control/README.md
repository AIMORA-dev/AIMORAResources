# Classic Case 0050 — TACS Thyristor Control

## Purpose

Two antiparallel thyristors connect a 60 Hz source to an R-L load. TACS reads
the source/load node voltages, integrates valve voltage, compares the
integrated flux-like signal with a firing reference, and sends grid commands
back to the controlled switches.

## Control and network equations

For valve \(k\), the control integrator owns

\[
\lambda_k(t)=\int v_{\mathrm{thy},k}(t)\,dt.
\]

The firing comparator produces a grid command when the integrated value
crosses the reference \(\lambda_{\mathrm{ref}}\). The conducting valve then
changes the nodal topology. The load obeys

\[
v_{\mathrm{load}}=Ri+L\frac{di}{dt}.
\]

The important mutation order is network voltage → TACS input → integrator and
comparator → switch command → next accepted network state.

## Inputs and run

The normalized public deck uses a 50 µs timestep, a 0.1 s horizon, a 150-unit
60 Hz source, an explicit reference value `LAMDAR = 0.4`, and two grid
controlled switch cards.

```bash
make run
```

The SVG should show chopped load/source behavior and TACS output transitions.
The CSV includes all requested network and control channels. See
[../SOURCE.md](../SOURCE.md) for every spelling/card correction; the runner
executes Julia only.

## Outputs and interpretation

- `classic_case0050_tacs_thyristor_control_timeseries.csv` contains source/load voltages, valve state/current, and requested TACS signals.
- `classic_case0050_tacs_thyristor_control_waveforms.svg` overlays the selected network and control transitions.
- `summary.md` records timestep, horizon, channel count, and peak magnitude.

Relate each firing transition to the integrated valve-voltage threshold, then confirm that only the forward-biased commanded thyristor conducts and that load current follows the R–L time constant. A topology change before the corresponding TACS decision would violate the documented mutation order.
