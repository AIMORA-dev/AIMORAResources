# Three-Phase Sampled Measurement Chain

This redistributable synthetic case executes an unbalanced three-phase nodal source, one passive analog filter per channel, an exact 20 kHz clock, deterministic 100 µs delay, clipping and ties-to-even quantization, instantaneous/RMS/fundamental-phasor outputs, symmetrical components, frequency estimation, complete digital snapshot state, and synthetic COMTRADE serialization. The 5 ms magnitude event tests same-path estimator validity and deterministic replay.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 fixed 10 µs physical steps, release 199 ordered samples, and reproduce every filter, clock, queue, window, phasor, frequency, and output-cursor state exactly.

## Outputs and limits

Inspect `measurement_waveforms.svg` for all three physical phases and the delayed held phase-A output around the 5 ms event; `measurement_diagnostics.svg` should show the expected positive/negative-sequence response, frequency estimate, and causal validity transition. The corresponding `.csv` files expose the exact plotted data. This generic product does not claim PMU, merging-unit, IEC/IEEE protected-standard, calibration, field-recording, protection, synchrophasor, ATP/PSCAD, HIL, or certification conformance.
