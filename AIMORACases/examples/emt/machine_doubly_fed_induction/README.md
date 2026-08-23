# Doubly Fed Induction Machine

This redistributable generic product executes a wound-rotor induction generator with an explicit d/q rotor electrical port, positive-into-machine stator and rotor powers, shaft state, a source-unbalance and torque event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI parameters define the stator, wound rotor, declared d/q rotor port, shaft, and fixed electromagnetic timestep. Positive stator and rotor electrical powers enter the machine, while positive shaft torque follows the declared mechanical direction. The rotor port is a machine boundary, not a converter model, prescribed trace, or converter-control claim. The data establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner applies the event, exercises split restart, and rewrites the deterministic artifacts.

## Outputs

- `machine_waveforms.csv` records stator and rotor-port quantities, speed, slip, torque, power, energy, event, and residual diagnostics.
- `machine_report.txt` and `summary.md` state the family, port orientation, restart identity, and limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show electrical and shaft behavior.

## Interpretation

Inspect stator, rotor, and mechanical power together: their signs must follow the positive-into-machine convention and their balance must agree with stored and dissipated energy. Speed and slip should respond continuously to the torque event, residuals must remain within reported bounds, and the restored trajectory must reproduce uninterrupted execution exactly.
