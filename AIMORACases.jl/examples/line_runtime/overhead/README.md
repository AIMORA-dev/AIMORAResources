# Coupled Overhead-Line Runtime

## Model and limits

This public example consumes the exact accepted generic overhead-line parameter and complete coupled fit artifacts, discretizes the full six-port scattering realization at a fixed 10 µs timestep, initializes its discrete sinusoidal state, and executes it through the production nodal backend without replacing it by a scalar, constant-parameter, or modal-only line.

## Run

Run `make run` from this directory. The 2 ms trajectory applies a phase-A receiving-end fault from 0.75 ms through 1.25 ms, retains every mutual companion term, writes terminal waveform and energy/KCL data, creates two curated SVGs, writes a typed portable snapshot, and proves exact continuation from the midpoint snapshot.

## Outputs and interpretation

The curated `runtime_waveforms.svg` and `runtime_energy.svg` figures accompany the deterministic waveform, energy/KCL, uncertainty, refinement, report, and snapshot artifacts.

The exact declared 110 Ω·m soil alternative is executed through the same timestep, discrete initialization, event schedule, channels, and snapshot/restart policy. `runtime_uncertainty.csv` publishes time-aligned voltage, current, power, energy, and KCL envelopes; the summary records both exact fit identities and keeps the incomplete uncertainty set explicit.

The nominal and declared alternative trajectories are also repeated at 5 µs with the same event boundaries and exact restart policy. `runtime_refinement.csv` publishes the time-aligned 10/5 µs voltage, current, power, energy, and KCL differences without relabelling the refined trajectory as an external oracle.

Interpret the waveform and energy plots together: the fault response must retain phase coupling, terminal KCL must remain within the reported bound, and restored continuation must match the uninterrupted trajectory exactly.

The example is synthetic and bounded to its recorded L200/L205 fit, phase/port order, 1 Hz–10 kHz band, timestep, and generic data. It does not claim ATP/PSCAD equivalence, ULM-file compatibility, vendor or field accuracy, protected-standard conformance, or certification.
