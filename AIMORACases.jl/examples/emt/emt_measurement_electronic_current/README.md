# Electronic Current-Sensor Measurement Chain

This redistributable synthetic case executes an explicit series-loading electronic current sensor, passive continuous-time transducer state, accepted-step analog filtering, exact sampling, deterministic delay, clipping/quantization policy, causal estimators, checkpoint state, and synthetic COMTRADE output. The source event at 5 ms tests that loading, transducer, filter, and delayed outputs remain ordered and restartable.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 physical steps, release 199 samples, and reproduce the complete sensor and acquisition state exactly.

## Outputs and limits

Inspect `measurement_waveforms.svg` for the loaded current observation, transducer response, and delayed held sample around the 5 ms event; `measurement_diagnostics.svg` should show causal RMS, phasor, and validity trajectories without an early sample release. The corresponding `.csv` files expose the exact plotted data. The generic state-space matrices and network load are not a Rogowski coil, optical sensor, manufacturer transfer function, calibration, merging-unit standard claim, field recorder, protection, ATP/PSCAD, HIL, or certification.
