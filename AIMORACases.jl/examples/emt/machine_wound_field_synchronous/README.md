# Wound-Field Synchronous Machine

This redistributable generic product executes a three-phase, explicit-neutral wound-field synchronous generator with field and d/q damper circuits, convex cross-saturation, shaft state, one command event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI parameters own phase and neutral terminals, field and damper circuits, a convex cross-saturation law, shaft state, and a fixed electromagnetic timestep. Positive terminal current and power enter the machine; positive shaft torque follows the declared mechanical direction. Field, damper, and saturation state remain explicit rather than being replaced by an ideal voltage source. The data establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner applies the command event, exercises split restart, and rewrites all public artifacts.

## Outputs

- `machine_waveforms.csv` contains phase, field, damper, axis, speed, torque, power, energy, event, and residual quantities.
- `machine_report.txt` and `summary.md` record family, source identity, saturation, timestep, restart, and limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show electrical and shaft response.

## Interpretation

Inspect the electrical waveform for the command-event response and the mechanical plot for continuous speed and torque. Cross-saturation derivatives must remain reciprocal and energy-consistent, KCL and energy diagnostics should stay within the report bounds, and the restored trajectory must reproduce uninterrupted field, damper, saturation, shaft, and output state exactly.
