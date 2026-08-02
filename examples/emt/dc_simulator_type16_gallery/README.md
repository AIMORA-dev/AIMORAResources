# Type-16 DC-Simulator Source Gallery

This Julia-only gallery compares the fixed-field and comma-separated forms of
the two-card type-16 DC-simulator source. Both inputs must produce the same
typed source rows, startup topology, initialization, and timestep behavior.

The controller senses the terminal difference

\[
e(t)=v_{P1}(t)-v_{P2}(t)
\]

and represents a gain-limited lead/lag structure whose continuous design form
is

\[
G(s)=K\frac{1+sT_n}{(1+sT_1)(1+sT_2)}.
\]

AIMORA discretizes the supplied coefficients at the declared 1 ms timestep,
initializes the controller from the terminal-voltage difference, creates the
bridge/reference nodes, two positive resistances, an isolation branch, a timed
switch, successor source state, and balancing sources. The balancing
injections obey Kirchhoff's current law; their algebraic sum is zero.

Time constants and switch delays are seconds, isolation resistance is ohms,
balancing frequency is hertz, node voltages are volts, and generated source
currents are amperes. The clamp limits are -10 to +10 in the controller's
declared output unit.

## Inputs and assumptions

- `fixed_field_type16.deck` uses positional fixed columns.
- `free_field_type16.deck` uses comma-separated fields and Fortran-style `D`
  exponents as accepted electrical input syntax; it contains no Fortran code.
- Both decks run for 4 ms and are expected to produce identical typed physical
  parameters despite their different text layouts.

## Run

```bash
make run
```

## Outputs

Each input writes `*_timeseries.csv` and `*_waveforms.svg`.
`outputs/gallery_metrics.csv` exposes any difference in timing, dimensions, or
peak values; `outputs/summary.md` records the common finite Julia execution.

These cases were promoted from the type-16 validation suite and require no ATP
or compiled reference at runtime.
