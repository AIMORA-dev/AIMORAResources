# Specialized Switch-Type Gallery

This gallery runs two stateful switch models:

- a current-zero opening switch (type 3), which waits for current extinction
  after its opening command;
- a type-76 time-controlled resistance, which changes conductance over a
  prescribed interval.

The current-zero condition is

\[
t\ge t_{\mathrm{open}},\qquad
|i(t)|\le I_{\mathrm{extinction}},
\]

after which the topology changes from \(G_{\mathrm{on}}\) to
\(G_{\mathrm{off}}\). The type-76 conductance follows the card's time window
and resistance-state parameters. AIMORA rebuilds or updates the sparse system
after the state mutation and then records switch voltage/current.

## Run

```bash
make run
```

## Results

- `current_zero_*`: voltage/current waveforms for current extinction.
- `type76_*`: time-controlled resistance waveforms.
- `switch_metrics.csv`: samples and peak node/output values.
- `switch_type_gallery.svg`: one representative output from each model.
- `summary.md`: finite-result and case-count checks.

Times are seconds, resistance is ohms, current is in the deck's electrical
units, and the source waveform is evaluated by AIMORA's Julia runtime.

## Interpretation

Inspect the current-zero CSV around the opening command: current may continue until the extinction condition is met, and only then should the switch voltage/topology change. Compare that event-driven behavior with the type-76 trace, whose resistance follows its prescribed time interval regardless of a current zero. The combined SVG makes the different state-transition rules visible without treating either switch as an ideal instantaneous breaker.
