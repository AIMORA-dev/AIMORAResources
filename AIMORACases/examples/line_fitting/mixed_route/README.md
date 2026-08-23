# Separately Fitted Mixed Route

This public product demonstrates the required boundary for a route containing unlike propagation media. Its 1 km overhead and 500 m phase-mapped cable sections use one homogeneous-soil record, but each uniform segment receives its own coupled response, modal preparation, common-pole fit, continuous passivity certificate, and enforcement report. Layered-soil fitting remains covered independently rather than hidden in this route example.

## Run

Run `make run` from this directory. The command evaluates both segments over the same 81-point band from 1 Hz through 10 kHz, prepares nominal 100-ohm-m soil responses and one 110-ohm-m alternative for each segment, activates the separately installed production backend, and replaces the files under `outputs/` deterministically.

## Outputs and interpretation

The output prefixes every fit `.toml`, report, response, error, and sampled-passivity `.csv`/`.svg` artifact by segment and records their ordered source and fit signatures in `mixed_route_fit_summary.txt`. Inspect both reports for their independent selected orders, continuous passivity certificates, physical-admittance perturbations, source-frequency identities, conditioning, and bounded-alternative status. The two response/error plot pairs should be interpreted separately because the route media and phase ordering differ. The summary must state `length_averaged_uniform_fit_created=false`; that confirms no length-averaged mixed-route matrix was fitted as though it were one uniform propagation medium. Sampled SVG passivity curves remain diagnostics, while each report's Hamiltonian result is the continuous-frequency authority.

The example prepares immutable frequency-domain artifacts only. Transition-joint behavior, histories, network execution, switching, faults, restart, and ULM runtime remain outside this product.
