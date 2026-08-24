# Performance execution modes

This public example records the equal-accuracy execution definitions and the accepted native-Linux tower crossover for deterministic serial CPU, sparse CPU, threaded independent batches, local-process independent batches, and the admitted native CUDA fixed-admittance batch.

The small analytic solve is independently reproducible without the private solver. Larger rows are public workload definitions and reviewed aggregate results; they do not expose private kernels or claim speedup on another machine. CUDA is selected only at or above the measured 256-right-hand-side crossover on the recorded RTX 3060 profile. Unavailable modes return typed refusals, and explicit fallback occurs only before execution.

## Run the example

From this directory, run `make run`. The runner loads the public AIMORA environment, solves the small deterministic reference system, evaluates its scaled residual and exact result identity, and writes the reviewed P0–P2 workload definitions. The public example does not require access to `AIMORASolvers.jl`; production sparse and local-process kernels are qualified separately in the private validation repository.

## Output artifacts

`outputs/mode_summary.csv` records each execution mode, workload size, admission boundary, measured or unavailable status, equal-accuracy tolerance, and retained-memory result. `outputs/cuda_crossover.svg` plots the reviewed CPU/CUDA crossover for the exact recorded hardware and software profile. These committed artifacts are reproducible public evidence, not a promise that unrelated hosts have the same crossover.

## Interpret the results

Confirm that the analytic maximum error and scaled residual remain inside their declared tolerances and that every execution row preserves the same complete-result contract. The SVG should show CUDA becoming admissible only at 256 right-hand sides. Sparse, threaded, process, or CUDA labels indicate execution ownership; they never permit a fidelity, tolerance, output, or determinism change. Hardware or worker failure must produce a typed refusal rather than a partial result or a silent mid-run fallback.
