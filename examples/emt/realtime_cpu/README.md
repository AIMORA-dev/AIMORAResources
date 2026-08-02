# Fixed-Step CPU Timing

This example measures whether a Julia inverter step can execute within a
20-microsecond budget. It is a software timing study, not a claim of hard
real-time hardware qualification.

## Model, units, and assumptions

The timed kernel advances the same average-value inverter state used by the standalone inverter example for 50 ms at a requested 20 µs step, or 2,500 updates. Durations are seconds and reported execution statistics are seconds converted to microseconds for display. Compilation is excluded from the measured callback, `realtime=false` avoids deliberate wall-clock pacing, and results depend on CPU, Julia version, operating-system scheduling, power state, and competing processes.

## Run

```bash
make run
```

## Output

`realtime_summary.json` records the step count, requested timestep, mean and
maximum execution time, and budget overruns.

Run this example on the intended workstation with other workloads controlled.
Compilation time is outside the measured timestep loop.

## Interpretation

The mean indicates typical computational cost, the maximum exposes the slowest observed update, and overruns count samples above 20 µs. Zero overruns in one run is encouraging but does not prove a hard deadline; qualification requires repeated measurements, controlled hardware, allocation analysis, and an actual real-time execution environment. Use this artifact to compare configurations on the same machine.
