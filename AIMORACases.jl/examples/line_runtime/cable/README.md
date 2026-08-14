# Coupled Cable Runtime

## Model and limits

This public example consumes the exact accepted generic three-single-core cable parameter and complete coupled fit artifacts. It executes the full six-port phase-domain state realization with sheath- and earth-return effects already retained by the admitted L200/L205 source rather than substituting a constant-parameter or independent-phase approximation.

## Run

Run `make run` from this directory. The fixed-step trajectory uses exact discrete sinusoidal initialization, applies and clears a phase-A receiving-end fault, records currents, voltages, energy and KCL, writes curated SVGs, and proves exact typed snapshot restart.

## Outputs and interpretation

The curated `runtime_waveforms.svg` and `runtime_energy.svg` figures accompany the deterministic waveform, energy/KCL, uncertainty, refinement, report, and snapshot artifacts.

The exact declared 110 Ω·m soil alternative executes through the identical runtime and restart policy. The uncertainty CSV publishes time-aligned voltage, current, power, energy, and KCL envelopes while the summary records exact nominal/alternative fit identities and states that unmodelled uncertainty remains unknown.

The example repeats the nominal and declared alternative trajectories at 5 µs with identical event boundaries and restart policy. `runtime_refinement.csv` reports time-aligned 10/5 µs voltage, current, power, energy, and KCL differences; it is timestep evidence, not an external-oracle claim.

Interpret the electrical and energy plots together: the fault response should preserve complete phase coupling, terminal KCL must stay within the reported bound, and restored continuation must reproduce the uninterrupted trajectory exactly.

The result is a generic bounded product. It is not manufacturer data, a ULM-file claim, ATP/PSCAD equivalence, a protected-standard result, a field measurement, or certification.
