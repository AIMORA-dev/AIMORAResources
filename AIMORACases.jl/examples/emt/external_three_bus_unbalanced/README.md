# External Three-Bus Unbalanced Feeder Adaptation

This is a Julia-only EMT adaptation of the topology and selected public data
in PowerModelsDistribution's OpenDSS `case3_unbalanced.dss`. It retains:

- a 50 Hz, 0.4 kV-class stiff three-phase source;
- two three-phase line sections;
- the upstream diagonal R/X values;
- a 9:6:6 phase-load ratio.

AIMORA currently uses a transparent per-phase R–L teaching model here. Mutual
line terms, constant-power load iteration, and OpenDSS unit conversion are not
claimed equivalent. This case is therefore an educational transient
adaptation, not a power-flow benchmark result.

## Model, units, and assumptions

The prescribed source frequency is 50 Hz and the study integrates with a 50 µs timestep for 20 ms. Source and reported bus voltages are normalized in per unit; the source description retains the public 0.4 kV class as engineering context. Each phase is represented by an independent series R–L path and a phase-dependent load, with no mutual coupling, neutral conductor, regulator, shunt capacitance, or iterative constant-power behavior.

## Run

```bash
make run
```

## Outputs

- `three_bus_unbalanced.csv`: source, primary, and load-bus phase voltages.
- `load_bus_waveforms.svg`: unbalanced receiving-end waveforms.
- `summary.md`: RMS voltages and phase-sum imbalance.

See `SOURCE.md` and `UPSTREAM_LICENSE.md` for the immutable source revision and
redistribution terms.

## Interpretation

Phase A should experience the largest load-related drop because it carries the largest share, while phases B and C remain similar. Use RMS values to compare magnitudes and the phase-sum metric to quantify imbalance. Differences from an OpenDSS result are expected because this is a documented AIMORA teaching adaptation, not an equivalence claim.
