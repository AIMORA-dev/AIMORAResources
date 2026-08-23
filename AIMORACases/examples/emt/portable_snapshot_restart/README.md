# Portable EMT Snapshot and Exact Restart

This redistributable Julia case advances a fixed-step Bergeron-line network to an accepted synchronization point, writes a canonical `portable_full` snapshot, inspects its solver-free descriptor, reconstructs a new private-backend workspace, and proves byte-exact split versus uninterrupted continuation. Repeated capture produces identical bytes and SHA-256 identity.

The runner also writes a `portable_public_reference` snapshot containing only a small public accepted-state record. It can be decoded without a private solver. Deliberate envelope corruption and a changed model identity are rejected before state mutation.

## Run

```bash
make run
```

## Output artifacts

The runner writes the two `.aimora-snapshot` products, the split/uninterrupted waveform data in `portable_snapshot_restart.csv`, the matching figure in `portable_snapshot_restart.svg`, and `summary.md`. The summary records schema/profile/section identities, canonical byte counts and hashes, represented time and step, exact continuation, independent public readability, corruption and identity refusal, and the explicit private/public boundary.

The case qualifies AIMORA's version-1 canonical snapshot envelope and exact AIMORA continuation for the declared fixed-step network. It does not claim ATP/PSCAD restart compatibility, live migration, encryption, signatures, FMI/SSP/HELICS, DASSL, GPU state, hard-real-time/HIL behavior, hostile-input safety, certification, or portability on an operating system that has not been executed.
