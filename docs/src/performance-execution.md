# Performance execution

AIMORA keeps scientific fidelity fixed while changing execution placement. A performance comparison is valid only when project, equations, initialization, representation, model tier, timestep or tolerance, event and task order, complete outputs, and error bounds are identical.

## Modes

The public `AIMORA.PerformanceExecution` contract describes deterministic serial CPU, reusable sparse CPU, threaded independent batches, local-process independent batches, and admitted native CUDA fixed-admittance batches. The private production backend reports availability and prepares an explicitly requested mode; no unavailable mode is silently relabelled.

Sparse factors are reusable only while matrix structure, numeric values, scaling, topology, timestep, model modes, and solver options have the same exact signature. A numeric change refactorizes; a structural change repeats symbolic analysis and numeric factorization. Singular, nonfinite, stale, or inaccurate factors fail explicitly.

Threaded and local-process modes accept independent prepared jobs only. Each job has a stable input index and isolated mutable state, and results are published in input order rather than completion order. Local workers must load the exact Engine and Solver source identities. Worker failure or identity mismatch fails the batch without a hidden serial rerun.

Native CUDA is limited to the registered Float64 dense fixed-admittance many-right-hand-side kernel. On the accepted Linux tower and RTX 3060 profile, the first measured equal-accuracy crossover is 256 right-hand sides for a 96-node matrix; smaller batches are refused or may select CPU only through an explicit pre-execution fallback. This is not a universal or cross-machine speedup claim.

The canonical public example is `AIMORACases/examples/emt/performance_execution_modes`. It records the analytic P0 reference, P1 execution definitions, the 100,000-node sparse P2 storage tier, the 4,096-right-hand-side CUDA tier, residuals, errors, and the reviewed crossover curve.

## Limits

AIMORA does not claim general sparse or event-heavy GPU execution, multi-GPU execution, MPI, remote clusters, network fault tolerance, dynamic load balancing, bitwise equality across different linear-algebra backends, or speedup outside the exact measured systems. First execution, setup, transfer, synchronization, solve, output, and warmed execution remain separate measurements.
