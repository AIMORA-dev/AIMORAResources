# Classic Case 0010 — Parallel EHV Resonance

## Purpose

This is a steady-state-only classic input: its deck timestep and transient
horizon are both zero. Two long EHV circuits are represented by cascaded,
coupled PI sections with series capacitors, shunt reactors, breakers, and a
fault branch.

## Governing equations

At 60 Hz, AIMORA assembles the complex nodal equation

\[
Y(\omega)V=I,\qquad \omega=2\pi 60.
\]

The element impedances include

\[
Z_{RL}=R+j\omega L,\qquad
Z_C=\frac{1}{j\omega C},\qquad
Y_{\mathrm{shunt}}=\frac{1}{R+j\omega L}+j\omega C.
\]

The cascaded line sections retain their mutual terms before the phasor solve.
Voltage magnification indicates proximity to a network resonance; it is not
manufactured by a time-domain sine trace.

## Run and outputs

```bash
make run
```

The dedicated Julia steady-state runner writes:

- `classic_case0010_parallel_ehv_resonance_phasors.csv`, with real,
  imaginary, magnitude, and angle values for every node;
- `classic_case0010_parallel_ehv_resonance_voltage_magnitudes.svg`;
- `summary.md`, with frequency, source/node counts, and maximum magnitude.

Use the complex CSV to compare phase angle as well as magnitude. Provenance:
[../SOURCE.md](../SOURCE.md).
