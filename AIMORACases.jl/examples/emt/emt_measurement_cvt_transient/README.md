# Coupling-Capacitor Voltage-Transformer Transient Chain

This redistributable synthetic case executes a CVT divider, tuned compensation reactor, suppression branch, electromagnetic unit, secondary burden, analog filter, exact sampler, causal delay, RMS and phasor estimators, and COMTRADE writer as one coupled product. The 5 ms source change reveals divider, compensation, electromagnetic, and digital-chain transients rather than replacing the CVT by an ideal ratio.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 fixed 10 µs steps, release 199 samples, and reproduce the exact coupled state after checkpoint restore.

## Outputs and limits

Inspect `measurement_waveforms.svg` for the divider, compensated secondary, and delayed sampled response around the 5 ms source change; `measurement_diagnostics.svg` should show bounded stored energy and KCL residuals followed by causal estimator validity. The corresponding `.csv` files expose the exact plotted data, and the synthetic CFG/DAT files prove the registered COMTRADE subset. The generic divider and tuning do not establish ferroresonance coverage, carrier-coupling behavior, manufacturer performance, protected accuracy class, field calibration, protection, ATP/PSCAD equivalence, HIL, or certification.
