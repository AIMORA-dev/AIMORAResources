# Multi-Mass Controlled Machine

This redistributable generic product executes an eight-mass wound-field synchronous machine with compliant shaft sections, excitation, governor and stabilizer tasks, limiter state, phase unbalance, a voltage-reference event, angular-momentum and energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI data define eight inertias, seven compliant shaft sections, field and damper circuits, sampled control tasks, limits, delays, and a fixed electromagnetic timestep. Positive terminal power enters the machine and shaft action/reaction signs follow the declared mass ordering. The shaft and controller data establish no turbine-generator, vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner executes the voltage-reference event and split restart and rewrites the artifacts.

## Outputs

- `machine_waveforms.csv` includes electrical, controller, limiter, shaft-speed, torque, angular-momentum, energy, event, and residual quantities.
- `machine_report.txt` and `summary.md` record task timing, mass count, state identity, restart, and limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show terminal and multi-mass response.

## Interpretation

The reference event should appear only on its declared task boundary. Inspect the mechanical plot for distinct but bounded mass-speed motion rather than a rigid-shaft substitution, and confirm action/reaction torque, angular momentum, and energy diagnostics remain consistent. The restarted result must match uninterrupted task, limiter, shaft, and electrical state exactly.
