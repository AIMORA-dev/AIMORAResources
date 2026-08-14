# Coupled Mixed-Route Runtime

This public example executes an overhead segment followed by a cable segment as two separate complete coupled runtimes. The transition explicitly maps the overhead `a,b,c` receiving nodes into the cable fit's `c,a,b` sending order through shared physical junction nodes; no length-averaged uniform route or hidden lower-fidelity line is created.

Run `make run` from this directory. Both exact L205 artifacts are discretized at 10 µs, initialized through one coupled frequency-domain network operating point, advanced through a receiving-end fault and clearing, snapshotted independently, and replayed exactly through the same junction network. Outputs contain waveforms, energy/KCL diagnostics, reports, typed snapshots, and curated SVGs.

Both exact declared 110 Ω·m soil alternatives execute together through the same segment order, `a,b,c` to `c,a,b` junction map, timestep, initialization, fault schedule, outputs, and per-segment snapshot/restart policy. The published uncertainty envelope therefore retains the physical route and never substitutes a single averaged line; unknown alternatives remain explicit.

The complete nominal and two-alternative route is repeated at 5 µs with the same junction map, event boundaries, and exact per-segment restart. `runtime_refinement.csv` publishes time-aligned 10/5 µs voltage, current, power, energy, and KCL differences without treating either timestep as independent truth.

The generic route is bounded by the two recorded parameter/fit artifacts and their public licences. It does not claim a ULM import, ATP/PSCAD equivalence, vendor accuracy, field validation, protected-standard conformance, or certification.
