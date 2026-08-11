# TACS Network Feedback

This example closes a dynamic feedback loop between AIMORA's electromagnetic
network and typed TACS/control runtime:

1. the network voltage at `SENSE` is sampled;
2. a first-order transfer function computes `FILTER`;
3. `FILTER` drives a type-17 controlled source and a controlled switch;
4. the modified network is solved again in the same ordered timestep.

The control block is

\[
H(s)=\frac{1}{1+0.001s},
\qquad
0.001\dot y+y=u.
\]

The deck also supplies a 2-unit pulse and a 3-unit ramp so the report shows
both autonomous control functions and closed-loop electrical feedback. Source
and control values are in the deck's per-unit educational scale; the timestep
is 50 µs and the displayed horizon is 300 µs.

## Run

```bash
make run
```

## Results

- `control_network_feedback_timeseries.csv`: every node and requested control
  output.
- `control_network_feedback_waveforms.svg`: selected nonzero feedback signals.
- `summary.md`: timing, channel count, peak value, and interpretation.

The example executes only AIMORA Julia code. It is a user-facing counterpart
to the parser, control-expression, switch-coupling, and mutation-order
validation suites.
