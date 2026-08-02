# Bergeron and Frequency-Point Line Models

This example combines a fixed-step Bergeron travelling-wave line with a direct
frequency-domain line calculation. It shows both a transient workflow and the
underlying characteristic impedance/propagation quantities.

## Model, units, and assumptions

For the frequency point, AIMORA evaluates \(Z_c=\sqrt{z/y}\) and \(\gamma=\sqrt{zy}\) from the supplied series impedance and shunt admittance per unit length. The transient uses per-unit voltage, seconds, a 20 µs fixed step, a 40 µs Bergeron travel time, an ideal source, and a 1 pu matched resistance. The teaching line is scalar and loss configuration is deliberately simple; phase coupling and a broadband fitted line belong in `frequency_dependent_line`.

## Run

```bash
make run
```

## Outputs

- `bergeron_line_trace.csv`: source and receiving-end voltage samples.
- `bergeron_line_waveform.svg`: propagation delay in the receiving-end voltage.
- Console values for complex characteristic impedance and propagation constant.

The load-end waveform remains unchanged until the configured travel time has
elapsed. With a matched load, the arriving step should not produce a large
reflection.

## Interpretation

Read the CSV around 40 µs to distinguish source admission from the delayed receiving-end arrival. The matched termination makes a returning reflection small, so a large second step would suggest an incorrect characteristic admittance or history update. The printed complex \(Z_c\) and \(\gamma\) are a separate 60 Hz parameter calculation, not values fitted from the short waveform.
