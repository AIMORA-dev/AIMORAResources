# Finite Active Negative-Resistance R–L Branch

This example demonstrates a physically active series R–L branch with
\(R=-0.5\ \Omega\) and a 1 Ω inductive reactance at 60 Hz, corresponding to
\(L=1/(2\pi 60)=2.6526\ \mathrm{mH}\). Negative resistance supplies energy,
so AIMORA admits it only when the discrete companion remains finite and
nonsingular.

For trapezoidal integration, the branch current can be written

\[
i_n=G_{\mathrm{eq}}v_n+i_{\mathrm{hist}},\qquad
G_{\mathrm{eq}}=\frac{1}{R+2L/\Delta t}.
\]

With \(\Delta t=100\ \mu\mathrm{s}\), the companion denominator is approximately
\(52.55\ \Omega\), so its conductance is finite and positive even though the
continuous branch is active. A 10 Ω shunt and a 100 V, 60 Hz source keep the
short 1 ms demonstration bounded.

## Inputs and assumptions

- `active_negative_resistance_rl.deck` uses fixed-card resistance and
  reactance in ohms; AIMORA converts reactance to henries using the declared
  60 Hz power frequency.
- This is an active-device demonstration, not a passive-network model.
- Zero, nonfinite, or singular companion denominators remain invalid.

## Run

```bash
make run
```

## Outputs

- `outputs/active_negative_resistance_rl_timeseries.csv`: node voltages and
  requested branch channels.
- `outputs/active_negative_resistance_rl_waveforms.svg`: bounded transient
  response.
- `outputs/summary.md`: timestep, sample count, peak voltage, and
  interpretation.

The deck is parsed, initialized, stamped, stepped, and reported entirely by
AIMORA's Julia execution path.
