# Electronic Voltage-Sensor Measurement Chain

This redistributable synthetic case executes an explicit shunt-loading electronic voltage sensor, passive continuous-time transducer state, accepted-step analog filtering, exact sampling, deterministic delay, clipping/quantization policy, causal estimators, complete snapshot state, and synthetic COMTRADE output. A 5 ms source change exercises physical loading and the ordered digital path together.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 physical steps, release 199 samples, and reproduce the complete sensor/acquisition continuation exactly.

## Outputs and limits

Inspect `measurement_waveforms.svg` for the loaded voltage observation, transducer response, and delayed held sample around the 5 ms event; `measurement_diagnostics.svg` should show causal RMS, phasor, and validity trajectories without an early sample release. The corresponding `.csv` files expose the exact plotted data. The generic network and state-space matrices are not a capacitive divider, optical sensor, manufacturer transfer function, calibration, merging-unit conformance, field recorder, protection, ATP/PSCAD equivalence, HIL, or certification.
