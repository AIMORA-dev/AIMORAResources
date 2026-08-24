# Real-time and HIL interfaces

AIMORA provides a native-Linux soft-real-time fixed-step execution contract around the accepted EMT mutation order. Deadline pressure never changes equations, fidelity, timestep, events, tasks, controls, or outputs, and it never skips or duplicates a scientific step.

## Admitted software targets

The initial targets are a preallocated in-process controller, a bounded connected localhost UDP loopback, and an AIMORA-authored C shared-library controller using ABI version 1 and an exact SHA-256. UDP frames carry an ABI, sequence, logical monotonic timestamp, channel count, configuration identity, and finite payload; stale, duplicate, reordered, wrong-identity, oversized, or closed transports fail explicitly. The C interface validates the file hash, symbols, ABI, state size, reset status, step status, finite values, and controller-state checkpoint.

For epoch `t0`, period `h`, and logical step `k`, the absolute monotonic release is `r_k=t0+k*h` and the deadline is `d_k=r_k+h`. AIMORA retains every timing sample plus minimum, median, p90, p99, p99.9, maximum response, maximum wake jitter, and overrun count. An observed zero-overrun run is evidence only for the exact machine, kernel, workload, period, and load profile.

Every channel declares direction, physical unit, affine scale and offset, raw range, and safe physical value. Preparation binds an exact channel identity. Failure before acceptance restores the caller-owned model checkpoint where possible, restores controller state, latches safe outputs, invalidates the interface, and publishes no partial scientific step.

The public `realtime_loopback` example compiles the AIMORA C fixture headlessly, executes 100 paced steps, compares the complete closed-loop recurrence with an independent Julia formulation, and writes timing CSV, summary CSV, and SVG response-time output. The registered P2 tower profile exercises all 4,096 admitted software channels with zero observed overruns at its declared 10 ms period.

## Explicit unavailable boundary

The installed tower uses `PREEMPT_DYNAMIC`, so AIMORA reports `hard_realtime_unavailable` for hard-real-time requests. Physical controller-HIL, relay-HIL, power-HIL, calibrated analog or digital I/O, vendor targets, fieldbus conformance, and safety certification return typed unavailability unless exact hardware, driver, calibration, interlock, safe-state, and external evidence are registered. Software loopback is never labelled physical HIL.

DASSL and GPU deadline execution are not admitted real-time modes. The optional DASSL-class solver remains an offline analysis choice, while real-time execution remains fixed-step `InstantaneousEMT`.
