# Contributing

Keep each change inside the canonical resource path named by `resource-index.toml`, preserve package UUIDs and public APIs, and update provenance and licences with any imported material. Do not copy private validation data, restricted cases, proprietary simulator inputs or outputs, credentials, or private repository metadata into this public repository.

Generated bulk outputs follow `artifact-policy.toml`: canonical inputs, reproducible runners, concise metrics, schemas, hashes, small independent references, and selected explanatory figures may be retained, while raw waveforms, repeated renders, reports, logs, caches, intermediates, duplicate formats, and large checkpoints are generated outside Git by default. Existing accepted artifacts remain preserved until their individual classification and ledger boundary permit a change.

Before publication, run `julia test/runtests.jl`, the tests for every changed package or content owner, and the affected AIMORA integration/validation gate. Publish one coherent Resources commit after the complete resource change is ready.
