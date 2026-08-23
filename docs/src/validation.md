# Validation

Validation keeps production execution and each evidence class separate:

1. `AIMORA.jl` owns production Julia models, orchestration, typed state, and outputs.
2. `AIMORAReferenceModels` owns small independent mathematical challengers such as matrix transforms, ideal PWM duties, controller formulations, and analytical branch responses; it does not reuse production stamps, histories, events, or solver algorithms.
3. `AIMORACases` owns complete user-facing studies that execute the real engine and publish deterministic data, figures, and summaries.
4. `BPAEMTPReference.jl` builds and runs the historical compiled program as an external oracle for retained BPA behavior only.
5. Controlled private qualification aligns cases, stages, variables, units, domains, and tolerances and then evaluates local, independent, coupled, adversarial, performance, regression, and release evidence.

The compiled reference is never loaded by a production AIMORA study and cannot validate modern science absent from BPA EMTP. Julia-authored analytic, manufactured, and contract checks are independent design/science evidence, not compiled-reference equivalence. A public case proves complete real-engine usability; a reference model proves a bounded result against a separately formulated challenger, so those repositories are complementary rather than duplicated.

Modern EMT evidence uses E0 charter/provenance, E1 local equations/invariants, E2 independent solution, E3 coupled physics, E4 external reference, and E5 release robustness. E4 is not applicable to the first switch-detailed VSC because it invokes no external simulator, publication benchmark, experiment, measured device, manufacturer data, standard-conformance behavior, or certification; all claims remain internally and independently bounded.

The historical Fortran build intentionally uses its instrumented `-O0` path. Modern optimization is unsafe for source that depends on legacy storage and evaluation behavior.
