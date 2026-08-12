# General Multirate EMT Task Platform

This redistributable Julia case executes sixteen exact rational schedules across all eight public task families inside a real hybrid EMT network. A physical event at 75 microseconds collides with six task activations and three delayed releases; AIMORA applies the event first, then performs each task's `read → compute → enqueue → write → hold` stages in declared dependency order. The final held command drives an existing controlled EMT source, so the electrical trace and task trace are produced by one coupled run.

The case also serializes an in-process integrator at an accepted boundary and proves exact continuation, then injects a task failure at the event collision and proves that the event mutation and every partial task occurrence are rolled back. This is an S210 checkpoint-continuation demonstration, not the portable cross-process snapshot format reserved for later platform work.

## Run

```bash
make run
```

The generated `summary.md` records family and stage counts, collision coverage, maximum pending depth, the typed rollback failure, and the deterministic result signature.

The task recurrences are synthetic and dimensionless. They qualify AIMORA's exact calendar, dependency, delayed-hold, event-order, rollback, restart, and result contracts only; they do not qualify protection, carrier, converter-control, machine, source, thermal, interface, or user-defined physics. The case makes no ATP, PSCAD, FMI, HELICS, hard-real-time, HIL, protocol-conformance, safety, or certification claim.
