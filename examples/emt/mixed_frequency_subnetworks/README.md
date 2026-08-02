# Mixed-Frequency Steady-State Subnetworks

This case places a 50 Hz source/load pair and a 60 Hz source/load pair in two
electrically disconnected subnetworks. AIMORA assigns frequency by connected
component, solves both phasor networks, and initializes a single EMT trace
whose channels retain their own angular frequency.

For each subnetwork,

\[
\underline V_L =
\underline V_S
\frac{Z_L}{Z_S+Z_L},
\qquad
Z_S=R+jX\frac{f}{60\ \mathrm{Hz}}.
\]

The first source is \(100\angle0^\circ\) peak V at 50 Hz. The second is
\(120\angle30^\circ\) peak V at 60 Hz. Both feed 10 Ω loads through a
\(1+j1\) Ω branch specified on a 60 Hz reactance base.

## Run

```bash
make run
```

## Results

- `mixed_frequency_waveforms.csv`: node voltages for both frequency islands.
- `mixed_frequency_waveforms.svg`: simultaneous 50 Hz and 60 Hz traces.
- `phasors.csv`: magnitude, phase, and assigned frequency for every node.
- `summary.md`: partition and finite-result checks.

Connecting the two islands with a branch or initially closed switch is
intentionally invalid because a single passive connection cannot have two
simultaneous steady-state frequencies. Those rejection cases remain private
validation tests, not user examples.

## Interpretation

Compare the phasor CSV against the plotted periods: the 50 Hz island completes fewer cycles than the 60 Hz island over the same time window, while each load magnitude/phase follows its own divider equation. Confirm that every node is assigned exactly its component frequency. The result demonstrates valid disconnected frequency ownership; it does not permit unlike-frequency buses to be connected directly.
