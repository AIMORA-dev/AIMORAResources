# Single-Phase Sine Source

This is the smallest time-domain waveform example in the gallery. A stiff
Thevenin source energizes a resistive load with

\[
v(t)=\hat V\sin(2\pi f t+\phi)+V_{\mathrm{offset}}.
\]

Here, \(\hat V=1\) pu, \(f=60\) Hz, \(\phi=0\), and the offset is zero.

## Model, units, and assumptions

Time is seconds, frequency is hertz, phase is radians in the Julia callable, and the reported source voltage is per unit. One 60 Hz cycle is sampled at 360 points, giving \(\Delta t=1/(60\times360)\approx46.296\) µs. The source is ideal and the example evaluates only its prescribed waveform; source impedance, a network load, harmonics, and measurement noise are intentionally absent.

## Run

```bash
make run
```

## Outputs

- `single_phase_sine.csv`: one complete cycle of sampled voltage.
- `single_phase_sine.svg`: the sine-wave plot.
- `summary.md`: equation, timestep, peak, and final value.

Change fields 5–8 of the `source` row in `run.jl` to experiment with amplitude,
frequency, phase, and DC offset.

## Interpretation

The waveform should start at zero, reach approximately +1 pu after one quarter-cycle, cross zero after one half-cycle, and return to zero after a full cycle. The summary and CSV expose exact samples for checking peak and period. Changing phase shifts the curve in time, while a DC offset moves its centreline without changing frequency.
