# Multi-Case Study Sequence

One input stream may contain several isolated studies. This example has:

1. a 1 pu source feeding a voltage divider;
2. an explicitly aborted case whose following card is discarded;
3. a 2 pu source feeding a second voltage divider.

`BEGIN NEW DATA CASE`, `END NEW DATA CASE`, `ABORT DATA CASE`, and the final
blank terminating card control the lifecycle. Every accepted case receives its
own parsed model and mutable EMT state.

## Model, units, and assumptions

Both accepted cases use constant per-unit sources, equal 2 Ω feeder/load resistors, a 50 µs step, and a 0.5 ms window. With no inductive or capacitive storage, each network is the algebraic divider \(v_{load}=v_sR_{load}/(R_{feed}+R_{load})\). Case state, node names, and source values are isolated; the aborted case must neither execute nor contaminate the following case.

## Run

```bash
make run
```

## Outputs

- `case_sequence.csv`: load-voltage waveforms from the two executed cases.
- `case_sequence.svg`: both isolated trajectories.
- `case_sequence_summary.toml`: execution kind, counts, and case boundaries.
- `summary.md`: accepted, aborted, and discarded-card counts.

The expected final load voltages are 0.5 pu and 1.0 pu because both cases use
equal feeder and load resistances.

## Interpretation

The two flat trajectories prove the divider values, while the TOML summary proves lifecycle behavior that a waveform alone cannot show. Confirm exactly two executed cases, one aborted case, and the expected discarded-card count. A 99 pu trace would reveal that aborted input leaked into execution; cross-case node/state reuse would reveal failed isolation.
