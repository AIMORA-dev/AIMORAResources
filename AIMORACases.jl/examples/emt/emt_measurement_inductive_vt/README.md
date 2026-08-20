# Inductive Voltage-Transformer Measurement Chain

This redistributable synthetic case executes a coupled two-winding inductive voltage transformer with explicit terminal resistance, inductance, burden, cable capacitance, analog conditioning, exact sampling, causal delay, RMS and fundamental-phasor estimation, deterministic restart, and synthetic COMTRADE output. A source magnitude event at 5 ms exposes the physical and digital transient path.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The accepted product contains 1,000 fixed 10 µs physical steps, 199 delayed samples, and an exact midpoint replay.

## Outputs and limits

Inspect `measurement_waveforms.svg` for the transformer and delayed held-sample response around the 5 ms event; `measurement_diagnostics.svg` should show causal estimator validity together with bounded stored energy and KCL residuals. The corresponding `.csv` files expose the exact plotted data. The generic parameters establish no manufacturer ratio/phase error, ferroresonance, protected accuracy class, calibration, field-recorder, protection, ATP/PSCAD, HIL, or certification claim.
