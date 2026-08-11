# Transmission Fault Switching

This larger three-phase example combines distributed-line behavior, a fault
connection, and breaker timing. It demonstrates how a study can request many
waveform channels from one Julia deck execution.

## Model, units, and assumptions

The fixed-card deck declares a 60 Hz, three-phase transmission system, mutually coupled source equivalents, line sections, a saturable transformer description, a phase-A receiving-end fault branch, and scheduled breakers. Time is seconds and the requested traces are normalized per unit by the Julia reporting layer; physical deck parameters retain their fixed-card engineering units. The declared run uses a 33.3 µs step and ends at 10 ms. Therefore the faulted initial interval is executed, but the 20 ms breaker opening and 96 ms fault clearing remain outside this particular horizon.

## Run

```bash
make run
```

## Outputs

- `transmission_fault_switching_timeseries.csv`: all node and requested output
  channels.
- `transmission_fault_switching_waveforms.svg`: the first six requested
  channels for a readable overview.
- `summary.md`: network size, timing, and peak voltage.

Use the CSV for detailed phase comparison. The SVG is intentionally limited to
six channels so switching and fault intervals remain legible.

## Interpretation

Treat this output as the pre-breaker faulted-network response and parser/runtime coverage for the full scheduled deck, not as proof that the later clearing sequence ran. Compare phases to see the asymmetry introduced by the phase-A fault and inspect requested terminal channels for finite coupled behavior. To study breaker opening and fault removal, extend the deck horizon beyond 96 ms and rerun after reviewing the longer-study timestep cost.
