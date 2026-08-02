# Source Waveform Gallery

This Julia-only gallery plots the source families available to EMT workflows:

- sinusoid and cosine;
- constant/DC;
- linear ramp;
- ramp followed by a linear slope;
- double exponential impulse;
- a custom fundamental plus third- and fifth-harmonic waveform.

## Model, units, and assumptions

All functions are sampled from 0 to 20 ms at 25 µs intervals. Time is seconds; the source values are dimensionless teaching amplitudes that may be interpreted on a user-selected voltage or current base. The sinusoid and cosine use 60 Hz, the DC level is 0.8, the ramp reaches 1 after 5 ms, and the custom signal is \(\sin\omega t+0.20\sin3\omega t+0.10\sin5\omega t\). No network response or interpolation error is included.

## Run

```bash
make run
```

## Outputs

- `source_waveforms.csv`: every sampled function.
- `standard_source_waveforms.svg`: built-in analytic source types.
- `harmonic_waveform.svg`: pure sine compared with a distorted waveform.
- `summary.md`: timestep and equations.

The custom harmonic expression illustrates that Julia callables can supply
waveforms beyond the predefined source-card families.

## Interpretation

Use the standard plot to compare start/stop and slope conventions among analytic source types. In the harmonic plot, the added odd harmonics sharpen and distort the fundamental without changing its 60 Hz period. The CSV is suitable for substituting new coefficients and checking exact sample values before connecting a source program to an EMT network.
