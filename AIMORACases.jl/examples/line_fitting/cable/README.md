# Coupled Cable Fitting

This AIMORA-authored public example converts one uniform three-single-core L200 cable segment into a complete shared-pole terminal scattering realization. It selects the smallest accepted order, preserves every coupling term, continuously certifies global passivity, and exposes fit and enforcement error in both wave and physical-admittance domains.

## Run

Run `make run` from this directory. The command evaluates 81 logarithmically spaced frequencies from 1 Hz through 10 kHz, prepares the nominal 100-ohm-m soil case and one 110-ohm-m alternative, activates the separately installed production backend, and replaces the files under `outputs/` deterministically. It does not download manufacturer data or depend on a proprietary simulator.

## Outputs and interpretation

The retained output contains the schema-versioned fit `.toml` and text report together with compact response, error, and sampled passivity `.csv`/`.svg` views. Inspect `coupled_line_fit_report.txt` to confirm the selected order, maximum fit error, continuous passivity certificate, physical-admittance perturbation, conditioning, effective rank, regularization, source-frequency identity, and bounded-alternative status. The response and error plots should show close agreement throughout the admitted band. The SVG passivity curve is a sampled diagnostic; continuous acceptance comes from the bounded-real Hamiltonian certificate recorded in the fit, and the single soil alternative demonstrates bounded sensitivity rather than a complete uncertainty distribution.

The product is preparation for a later runtime owner. It contains no convolution history, delay buffer, network stamp, switching event, restart state, ULM compatibility, or ATP/PSCAD equivalence claim.
