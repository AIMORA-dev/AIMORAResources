# Saturating and Remanent Current-Transformer Measurement Chain

This redistributable synthetic case executes a magnetic-equivalent-circuit CT with two flux-continuous limbs, explicit turns, leakage, winding loss, a Tellinen hysteresis material, nonzero remanent flux, and explicit burden/cable branches. The coupled electrical and magnetic endpoint is solved at every 10 µs step before the accepted signal enters the production filter, sampler, delay, RMS, phasor, and COMTRADE chain.

## Run

Run `make run` from this directory in an owner worktree with the production solver explicitly available. The command must accept 1,000 steps, preserve passive energy and magnetic continuity, release 199 samples, and reproduce the final state exactly after midpoint restart.

## Outputs and limits

Inspect `measurement_waveforms.svg` for remanence- and saturation-dependent secondary distortion around the 5 ms excitation change; `measurement_diagnostics.svg` should show causal estimates, bounded stored energy and KCL residuals, and the expected valid-sample transition. The corresponding `.csv` files expose the exact plotted data, and the CFG/DAT pair is a synthetic recorder product. The limiting curves and all parameters are generic AIMORA inputs, so this is not a named core, manufacturer transient-error prediction, protected CT class, calibration, protection study, field record, ATP/PSCAD equivalence, HIL qualification, or certification.
