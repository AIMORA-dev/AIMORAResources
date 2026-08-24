# Native-Linux Real-Code Loopback

This public case executes one fixed-step scalar plant against an independently compiled AIMORA C controller through the version-one shared-library ABI. It uses an absolute monotonic 10 ms calendar for 100 steps, records every response/jitter sample, compares the closed-loop trace with the independent Julia formulation, and writes CSV plus SVG outputs.

## Run the example

Run `make run` from this directory. A native Linux host and C compiler are required. The command invokes `julia --project=../../.. run.jl outputs`, compiles the exact controller source, verifies its SHA-256 identity, executes the paced loop once, and removes the generated shared-library build product rather than committing it.

## Output artifacts

`outputs/timing.csv` retains every scheduled release, wake time, response time, jitter, slack, and overrun observation. `outputs/summary.json` is the canonical machine-readable result, while `outputs/summary.csv` provides the same controller identity and aggregate timing distribution for tabular inspection. `outputs/response_time.svg` displays the complete response sequence rather than hiding the maximum behind a mean.

## Interpret the results

Confirm that the production loop and independent closed-loop formulation have the same accepted state, that the controller configuration and sequence identity remain exact, and that no output is published after a rejected step. The plot should show the measured soft-real-time response distribution for this run; it does not establish a portable deadline guarantee.

The case proves only the exact AIMORA-authored real-code software loopback on the recorded host/compiler/library hash. `PREEMPT_DYNAMIC` timing is soft real-time evidence. This is not PREEMPT_RT, physical controller-HIL, relay-HIL, power-HIL, calibrated I/O, vendor compatibility, fieldbus conformance, electrical safety, or certification. Any physical target remains unavailable until its hardware, driver, calibration, interlock, safe-state procedure, and external evidence are registered.
