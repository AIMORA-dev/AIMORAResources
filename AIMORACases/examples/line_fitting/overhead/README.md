# Coupled Overhead-Line Fitting

This AIMORA-authored public example converts one uniform three-phase L200 overhead segment into a complete shared-pole terminal scattering realization. It selects the smallest accepted order from 20, 40, 60, and 80 poles, continuously certifies global multiport passivity, records the physical-admittance effect of enforcement, and writes exact interchange and report artifacts.

## Run

Run `make run` from this directory. The command evaluates 81 logarithmically spaced frequencies from 1 Hz through 10 kHz, prepares the nominal 100-ohm-m soil case and one 110-ohm-m alternative, activates the separately installed production backend, and replaces the files under `outputs/` deterministically. It does not download private data or require a proprietary simulator.

## Outputs and interpretation

The retained output contains the schema-versioned fit `.toml` and text report plus compact response, error, and sampled passivity `.csv`/`.svg` views. Inspect `coupled_line_fit_report.txt` to confirm the selected order, maximum fit error, continuous passivity certificate, physical-admittance perturbation, conditioning, effective rank, regularization, source-frequency identity, and bounded-alternative status. The response and error plots should show close agreement throughout the admitted band. The sampled passivity figure is diagnostic only; the report's Hamiltonian certificate is the continuous-frequency passivity authority, and the alternative is an explicit sensitivity bound rather than a complete uncertainty distribution.

This is immutable frequency-domain preparation. It does not execute line histories, network stamps, switching, faults, restart, ULM files, or an EMT timestep, and it makes no ATP/PSCAD, vendor, standards, measurement, or certification claim.
