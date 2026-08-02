# Signed Source and Control Routing

This Julia-only example shows how fixed-card source routing keeps direction
separate from model selection. It includes ordinary sources, a type-17
controlled source, a type-60 source, a first-order TACS filter, a controlled
switch, and requested network/control outputs.

For a signed source identifier \(N_1\), AIMORA uses

\[
m=|N_1|,\qquad p=\operatorname{sign}(N_1),
\]

where \(m\) selects the physical source model and \(p\) preserves the terminal
or current-routing orientation. Reversing \(p\) reverses the routed injection
without changing the source family. The first-order control block follows

\[
\tau\frac{dy}{dt}+y=x,
\]

with \(\tau=1\ \mathrm{ms}\). Its output drives the controlled source and switch
before each network solve. Voltages are volts at fixed-card intake, control
signals are dimensionless unless the connected device assigns a physical
unit, time is seconds, and the timestep is \(50\ \mu\mathrm{s}\).

## Inputs and assumptions

- `signed_source_routing.deck` is an AIMORA fixed-card deck promoted from the
  signed-routing validation scenario.
- The 300 µs horizon is intentionally short and demonstrates mutation order,
  not long-term controller tuning.
- Source sign is routing metadata; it is not a negative model type.

## Run

```bash
make run
```

## Outputs

- `outputs/signed_source_routing_timeseries.csv`: node and requested source,
  switch, and control channels.
- `outputs/signed_source_routing_waveforms.svg`: selected routed signals.
- `outputs/summary.md`: timestep, dimensions, peak voltage, and physical
  interpretation.

The complete path is parsed and executed by AIMORA's Julia source, control,
timestep, nodal-solve, and reporting owners; no ATP or Fortran runtime is used.
