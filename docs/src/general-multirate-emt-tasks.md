# General Multirate EMT Tasks

AIMORA's general task platform provides exact deterministic logical-time execution for protection, carrier, converter-control, mechanical, source, thermal, interface, and user-defined task families. It schedules task-owned equations inside fixed-step instantaneous EMT; it does not supply or qualify those equations.

## Public declaration and private execution

`AIMORAProject.ControlTaskDeclaration` is the callback-free project owner. Each declaration carries a stable identity, one family, exact rational epoch/period/phase/computational delay in SI seconds, integer priority, declared read and write resources, explicit predecessors, and power-history/topology/interface/output invalidations. The versioned `aimora-control-schedule` format round-trips these declarations exactly and refuses unknown major versions.

The public Engine maps a declaration to `EMTTaskSpec`, validates a complete horizon with `emt_task_plan`, and exposes typed family, effect, logical-time, occurrence, checkpoint, result, and failure contracts. The separately distributed licensed numerical backend privately owns due-set selection, queues, callbacks, transaction integration, and state restoration. Public project inspection and package loading never require or reveal the private dispatcher.

```julia
using AIMORA
using AIMORA.EMTTaskPlatform

specification = EMTTaskSpec(
    "sampled_source",
    SourceEMTTask,
    emt_logical_time(0),
    emt_logical_time(25 // 1_000_000),
    emt_logical_time(5 // 1_000_000),
    emt_logical_time(2 // 1_000_000);
    priority = 0,
    read_resources = ["measured_voltage"],
    write_resources = ["source_command"],
)

plan = emt_task_plan(
    [specification];
    start = emt_logical_time(0),
    stop = emt_logical_time(1 // 1_000),
)
```

Floating calendar inputs are deliberately refused. Rational values are normalized into one exact quantum, and every activation/release boundary becomes a checked integer tick. The admitted domain is 1 ns through 1,000 s per period, phase in `[0, period)`, delay from zero through 100 periods, at most 1,024 tasks, 4,096 explicit dependency edges, one million activations per task, one billion horizon ticks, and 1,000 pending delayed values per task.

## Ordering, delay, and hold

At every exact instant, AIMORA applies localized physical events first and then due tasks. Task order is a stable topological order; simultaneously ready tasks break ties by `(priority, family, name, registration index)`. Two same-instant tasks with conflicting declared resources require a predecessor path. Cycles, missing predecessors, duplicate identities, and unordered read/write or write/write conflicts fail before accepted execution.

Each activation runs `read → compute → enqueue`. A due queued result runs `write`, after which the output remains held until another release. A zero-delay result can therefore write at its activation instant; a nonzero-delay result retains its originating sample index and exact release instant. Declared invalidations are applied only after a successful write.

## State, rollback, restart, and results

The scheduler checkpoints the exact plan identity, current and last accepted tick, occurrence history, invalidation flags, and every task's state, next activation, counts, last sample/write tick, held output, pending queue and queue cursor. At a same-instant failure, AIMORA restores the EMT transaction, event state, shared owner, task state, queue, counts, occurrences, and output to the last accepted boundary. A corrupt or stale checkpoint is a typed refusal, never a partial restore.

`EMTTaskResult` reports acceptance or a typed `EMTTaskPlatformFailure`, plan and deterministic SHA-256 signatures, exact occurrences, activation counts, maximum pending depth, invalidations, and a final checkpoint. Failure diagnostics identify the task, family, exact instant, stage, code, message, and exact last accepted instant.

The public [`general_multirate_task_platform`](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/general_multirate_task_platform) example executes sixteen period/phase combinations across all eight families. A 75 microsecond physical event collides with task activations and delayed releases; the final held output drives an existing EMT-controlled source. The example proves dependency order, event-first reads, delayed hold, exact split continuation, deterministic results, and full rollback after an injected callback failure.

## Validity and exclusions

The scheduler's calendar and ordering are exact; task-owned numerical and physical uncertainty remains with each task. S210 supports deterministic serial Julia callbacks embedded in fixed-step instantaneous EMT. The example recurrences are synthetic and do not qualify protection, carrier/device, converter-control, machine, source, thermal, interface, or user equations.

This boundary does not provide parallel/preemptive dispatch, stochastic tasks, adaptive global stepping, partition coupling, portable cross-process snapshots, FMI, HELICS, IEC 61850, ATP, or PSCAD compatibility, asynchronous wall-clock callbacks, hard-real-time deadlines, HIL, network-protocol timing, GPU dispatch, safety properties, standard conformance, or certification. Later capabilities must preserve S210's exact logical order while qualifying those separate domains independently.
