# Tabulated and Analytic Source Program

This example combines two input mechanisms used by an EMT source loop:

- a CSV time table, linearly interpolated between samples;
- an analytic ramp-then-slope signal assigned to a selected source slot.

The table has the required header `time_s,source_1,...,source_10`. The analytic
slot uses source type 13:

\[
s(t)=
\begin{cases}
C(t-t_0)/T_1, & 0\le t-t_0<T_1,\\
C+r(t-t_0-T_1), & t-t_0\ge T_1.
\end{cases}
\]

Here \(C=1\), \(T_1=5\) ms, and \(r=-50\ \mathrm{s}^{-1}\).

## Units and assumptions

The first CSV column is time in seconds and each source column carries values on the caller-selected source unit. Slot 2 is explicitly labelled volts; its analytic parameters therefore use volts and volts per second. Table samples must be ordered and finite, linear interpolation is used strictly between adjacent rows, and `:hold` retains the endpoint outside the table range. This program generates source values only and does not model a network or sensor bandwidth.

## Run

```bash
make run
```

## Outputs

- `source_program.csv`: interpolated and final accepted slot values.
- `source_program.svg`: slot 1 table interpolation and slot 2 analytic signal.
- `summary.md`: input provenance, assignment rule, and sample count.

Edit `source_signals.csv` to supply measured or externally generated source
signals. `extrapolation=:hold`, `:zero`, and `:error` are available.

## Interpretation

In the plot, slot 1 should pass exactly through every table sample with straight segments between them. Slot 2 rises linearly to 1 V at 5 ms and then decreases with the declared slope. The output CSV records both the provider value and final assigned slot, making replacement/combination rules auditable before the program drives an EMT source.
