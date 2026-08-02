# Frequency-Dependent Semlyen Line

This example constructs a one-mode frequency-dependent transmission line from
stable rational terms. A response term has the continuous form

\[
H(s)=\frac{rp}{s+p},\qquad p>0,
\]

and AIMORA converts it into fixed-step recursive convolutions while retaining
the travelling-wave delay. The receiving end feeds a resistive load.

## Model, units, and assumptions

Poles are positive inverse seconds, frequency is hertz, time is seconds, and plotted node voltages are per unit. The EMT trajectory uses a 50 µs timestep, a 20 ms duration, a 60 Hz source, and a one-mode line with a 115 µs travel time. The modal transformation is the identity because this is a scalar teaching case; the rational data are stable illustrative parameters rather than a fit to a named physical line.

## Run

```bash
make run
```

## Outputs

- `line_waveform.csv` and `line_waveform.svg`: sending/receiving voltage.
- `frequency_response.csv` and `frequency_response.svg`: propagation-response
  magnitude from 10 Hz to 10 kHz.
- `summary.md`: delay, update count, and reciprocity/passivity check.

Change poles, residues, characteristic admittance, or travel time to explore
fitted line behavior.

## Interpretation

The receiving waveform must respond only after the configured delay, and the response curve should remain finite and smooth from 10 Hz through 10 kHz. Use the physical-check flag and minimum phase-admittance eigenvalue to reject non-passive fits before trusting a transient. Changing a pole moves the corresponding memory time constant; changing a residue alters its contribution without changing the delay.
