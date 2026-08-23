# Permanent-Magnet Synchronous Machine

This redistributable generic product executes a salient permanent-magnet synchronous generator with three phases, explicit neutral, permanent flux, shaft state, a source-unbalance and torque event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI parameters own permanent d-axis flux, saliency, phase and neutral terminals, shaft state, and a fixed electromagnetic timestep. Positive terminal current and electrical power enter the machine; positive shaft torque follows the declared mechanical direction. Permanent flux is immutable machine data and cannot be replaced by a field winding or prescribed source. The data establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner applies the unbalance and torque event, verifies split restart, and rewrites the public artifacts.

## Outputs

- `machine_waveforms.csv` contains phase, axis, speed, torque, power, energy, event, and residual quantities.
- `machine_report.txt` and `summary.md` record flux identity, saliency, timestep, restart, and declared limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show electrical and shaft behavior.

## Interpretation

Inspect the electrical waveform for the unbalanced phase response and the mechanical plot for the torque-event response. Torque and power signs should agree with the permanent-flux and saliency convention, KCL and energy residuals should stay within the report bounds, and the restored trajectory must reproduce uninterrupted execution exactly.
