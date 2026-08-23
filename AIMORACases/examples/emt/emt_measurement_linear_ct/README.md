# Linear Current-Transformer Measurement Chain

This redistributable synthetic case executes a two-winding linear current-transformer apparatus, explicit series-RL and shunt-capacitance burden and cable branches, and the production analog filter, exact sampler, causal delay, sliding RMS, fundamental phasor, and deterministic COMTRADE path. The source changes at 5 ms, every physical step runs through the private nonlinear nodal backend, and the second half is replayed from an exact coupled checkpoint.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 fixed 10 µs steps, release 199 samples, and report exact restart.

## Outputs and limits

Inspect `measurement_waveforms.svg` for the primary, burdened secondary, and delayed held-sample response around the 5 ms source change; `measurement_diagnostics.svg` should show causal estimator validity and bounded energy and KCL residuals. The corresponding `.csv` files expose the exact plotted data, while the committed `outputs/` directory also contains a synthetic COMTRADE CFG/DAT pair and signed summary. This generic case proves the declared loading, timing, estimator, file, and restart path only; it is not a vendor CT, protected accuracy-class, calibration, field-recording, protection, ATP/PSCAD, HIL, or certification claim.
