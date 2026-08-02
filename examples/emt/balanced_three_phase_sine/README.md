# Balanced Three-Phase Sine Sources

This example creates three 50-Hz voltage sources separated by 120 electrical
degrees:

\[
\begin{aligned}
v_a(t)&=\sin(\omega t),\\
v_b(t)&=\sin(\omega t-2\pi/3),\\
v_c(t)&=\sin(\omega t+2\pi/3).
\end{aligned}
\]

## Model, units, and assumptions

The angular frequency is \(\omega=2\pi(50)\ \mathrm{rad/s}\), the sample interval is 50 µs, and all voltages are per unit with a 1 pu phase peak. The sources are ideal prescribed waveforms with zero sequence deliberately excluded; no line, load, source impedance, or numerical network solve is needed for this waveform identity example. Phase order is positive \(a\)-\(b\)-\(c\).

## Run

```bash
make run
```

## Outputs

- `balanced_three_phase.csv`: phase and line-to-line voltages.
- `phase_voltages.svg`: the three phase waveforms.
- `line_to_line_voltages.svg`: \(v_{ab}\), \(v_{bc}\), and \(v_{ca}\).
- `summary.md`: phase-sum error and the line/phase peak ratio.

For a balanced system, \(v_a+v_b+v_c\) should be nearly zero and the
line-to-phase peak ratio should be close to \(\sqrt{3}\).

## Interpretation

The CSV lets users verify the identities sample by sample, while the SVGs make phase order and displacement visible. A nonzero phase sum indicates amplitude or angle imbalance; a line/phase peak ratio far from \(\sqrt{3}\) indicates an incorrect subtraction, sampling window, or phase definition.
