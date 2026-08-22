# Portable EMT Snapshots

AIMORA portable EMT snapshots are canonical, versioned byte envelopes for one globally accepted fixed-step synchronization point. They preserve the scientific state needed for exact continuation without serializing a Julia object graph or a private sparse factorization implementation.

## Profiles and ownership

`portable_full` contains a public scientific-state inventory and a `private_reconstructible` section. The latter stores typed reconstruction values, not private source code, concrete private type names, factor bytes, caches, repository paths, or credentials. A public user can call `inspect_portable_emt_snapshot` to read the descriptor without decoding section values. Actual reconstruction requires an explicitly activated backend with the matching capability.

`portable_public_reference` permits public sections only and can be read without a production solver. It is intended for examples, independent reference values, format readers, and compatibility checks rather than production restart.

Every field has a stable identity, scientific owner, state family, unit, axes, and typed finite value. The accepted families cover continuous, algebraic, discrete, delayed, scheduler, random, history, output, checkpoint, and reconstruction state. Metadata binds the project, model, topology, settings, accepted rational time and step, capabilities, provenance, writer, numeric profile, compression profile, and minimum reader version.

## Canonical bytes and integrity

Records and sections use stable identity order, explicitly sized little-endian primitives, normalized UTF-8 text, exact rational clocks, IEEE-754 finite binary64 values with signed zero preserved, typed arrays, and no implicit host field order. SHA-256 binds each section and the complete envelope. Repeating capture at the same accepted state produces the same bytes and content identity.

Integrity is not authenticity. The format does not encrypt or sign state and does not make an untrusted file safe by itself. Callers must set file, payload, section, and nesting limits appropriate to their trust boundary and must obtain snapshots through an authenticated distribution path when authenticity matters.

## Capture and restore

Capture is permitted only after an accepted synchronization transition. AIMORA inventories the public and reconstructible state, validates cross-owner clocks and signatures, encodes temporary canonical bytes, decodes and verifies them, then atomically publishes the file.

Restore first bounds and validates the envelope, schema, digests, profile, capabilities, and project/model/topology/settings identities. It constructs an isolated workspace, restores public owners, asks the active backend to reconstruct private numerical state, verifies the restored inventories and next-residual boundary, and only then returns the candidate. Unknown versions, missing or duplicate owners, stale identities, resource-limit violations, corruption, unsupported private capability, and failed reconstruction produce typed failures without mutating an existing accepted workspace.

## Public workflow

The [`portable_snapshot_restart`](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases.jl/examples/emt/portable_snapshot_restart) example writes a `portable_full` snapshot, inspects its solver-free descriptor, restores it into a new workspace, and compares continued output exactly with uninterrupted execution. It also writes and publicly decodes a `portable_public_reference` snapshot and demonstrates corruption and changed-identity refusal.

```julia
descriptor = AIMORA.PortableSnapshots.inspect_portable_emt_snapshot(path)

restored = AIMORA.EMTStudy.read_portable_emt_workspace_snapshot(
    path,
    prepared;
    project_signature_sha256=project_sha,
    model_signature_sha256=model_sha,
    settings_signature_sha256=settings_sha,
)
```

## Compatibility and limits

Schema major version 1 readers accept registered version-1 minor migrations and reject unknown major versions or ambiguous migration paths. A changed physical model, topology, project identity, task/event program, settings, required capability, or state owner requires a new compatible artifact or an explicit registered migration; AIMORA never guesses.

The accepted product is an AIMORA fixed-step restart format on executed platforms. It does not claim ATP or PSCAD restart compatibility, cross-simulator interchange, FMI/SSP/HELICS conformance, live migration, encryption, digital signatures, hostile arbitrary-code deserialization, DASSL state, GPU state, real-time/HIL state, certification, or native portability on an operating system that has not been qualified. Delta snapshots and compression are not part of schema 1.1.
