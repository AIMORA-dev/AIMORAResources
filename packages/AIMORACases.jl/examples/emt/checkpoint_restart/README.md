# Checkpoint and Restart Continuation

This example runs the same switched line in two ways:

1. one uninterrupted 1 ms EMT simulation;
2. 0.5 ms, a typed AIMORA checkpoint, then a 0.5 ms restart.

The restarted trajectory is compared sample by sample with the uninterrupted
trajectory. This demonstrates a reproducible long-study or contingency
workflow without exposing raw global-memory dumps.

## Model, units, and assumptions

The two executions use identical per-unit electrical data, deterministic switch scheduling, a 50 µs fixed timestep, and the same 1 ms terminal time. The checkpoint owns typed Julia simulation state and integrity metadata; it is not a process-memory image and makes no promise of compatibility with arbitrary source-code or schema changes. The comparison assumes no external random input or concurrent mutation.

## Run

```bash
make run
```

## Outputs

- `checkpoint.aimora`: versioned Julia checkpoint with integrity metadata.
- `continued.aimora`: checkpoint after the continuation.
- `restart_report.json`: restart and physical-check report.
- `restart_comparison.csv`: uninterrupted, restarted, and error series.
- `restart_comparison.svg`: the two trajectories overlaid.
- `summary.md`: maximum state error and final KCL residual.

The acceptance condition is
\(\max_k |v_k^{full}-v_k^{restart}| \le 10^{-12}\) pu.

## Interpretation

An overlapping pair of traces and an error column below tolerance prove continuation equivalence at the saved boundary. This checks serialization, restored event/state ownership, and timestep ordering together; it does not by itself validate the physical line parameters against an external program.
