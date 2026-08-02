# Double-Circuit Overhead Line Constants

This study converts physical conductor geometry into phase and sequence
impedance/capacitance matrices with Carson earth-return corrections.

## Model, units, and assumptions

The study forms phase-domain series impedance and shunt admittance from conductor resistance, bundle geometry, height, frequency, and homogeneous-earth return, then transforms the six phase conductors into sequence quantities. The supplied case uses 60 Hz and 100 Ω·m soil resistivity. Geometry follows the fixed-card line-constants convention; exported impedance is Ω/mile, susceptance is mho/mile, attenuation is dB/mile, velocity is miles/s, and surge impedance is ohms. Conductors are longitudinally uniform and tower/ground-wire data are frequency independent.

## Run

```bash
make run
```

## Inputs

The catalogued deck defines two three-phase circuits, conductor resistance and
diameter, horizontal position, average height, frequency, and earth
resistivity.

## Outputs

- `line_constants_report.txt`: complete engineering report.
- `sequence_constants.csv`: surge impedance, attenuation, velocity, and R/X/B.
- `phase_impedance_matrix.csv`: complex phase impedance matrix.
- `sequence_impedance.svg`: sequence surge-impedance comparison.

This is a frequency-domain parameter study, so the SVG is a sequence comparison
rather than a time waveform. Confirm that the matrices are symmetric and that
the study reports `physical_checks_passed = true`.

## Interpretation

Positive- and negative-sequence values should coincide for a transposed balanced representation, while zero sequence differs because its return path includes earth and ground wires. Check matrix symmetry before using the constants in a line model, and inspect resistance/passivity signs. The SVG compares sequence rows at the configured frequency; it is not a transient voltage plot.
