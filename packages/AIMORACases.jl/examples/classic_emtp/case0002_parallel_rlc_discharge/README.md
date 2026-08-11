# Classic Case 0002 — Parallel RLC Discharge

## Purpose

This case starts with an energized capacitor and closes a switch at 0.5 ms,
allowing the stored energy to circulate through a parallel resistor and
inductor. It demonstrates initial conditions and topology mutation.

## Governing equations

For the common branch voltage \(v\) and inductor current \(i_L\),

\[
C\frac{dv}{dt}+\frac{v}{R}+i_L=0,\qquad
L\frac{di_L}{dt}=v.
\]

The energy at any instant is

\[
W(t)=\frac12 Cv^2+\frac12 Li_L^2,
\]

and \(dW/dt=-v^2/R\) after the switch closes. The deck contains
\(R=632.46\) Ω, legacy inductance/capacitance field values of 5, a 10 µs
timestep, a unit capacitor initial voltage, and the 0.5 ms switching event.

## Run and outputs

```bash
make run
```

The Julia runner executes the full 10 ms deck horizon and writes:

- `outputs/classic_case0002_parallel_rlc_discharge_timeseries.csv`;
- `outputs/classic_case0002_parallel_rlc_discharge_waveforms.svg`;
- `outputs/summary.md`.

Before closing, the capacitor retains its initial condition. Afterwards, the
voltage and inductor current exchange energy while resistance damps the
oscillation. This change at 0.5 ms is the main waveform feature to inspect.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
