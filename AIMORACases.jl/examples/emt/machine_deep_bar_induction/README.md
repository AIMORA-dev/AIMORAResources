# Deep-Bar Induction Machine

This redistributable generic product executes a three-phase, explicit-neutral induction motor with four passive rotor branches rather than a scalar slip-resistance substitution, plus shaft state, an event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI parameter set owns four ordered passive rotor branches, explicit slip and shaft state, and a fixed electromagnetic timestep. Positive terminal current and electrical power enter the machine; positive shaft torque accelerates the declared mechanical direction. No branch may be collapsed silently into a fitted scalar resistance. The data establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner executes the deterministic event and split restart and rewrites all public artifacts.

## Outputs

- `machine_waveforms.csv` contains terminal, rotor-branch, shaft, torque, power, energy, event, and residual quantities.
- `machine_report.txt` and `summary.md` record branch identity, family, timestep, restart, and public limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show the electrical and shaft response.

## Interpretation

Compare the event response with the pre-event operating region and confirm that speed and torque remain continuous at accepted steps. The retained branch state should produce a frequency-dependent rotor response without active energy creation; KCL and energy residuals should remain within the report bounds, and the restarted trajectory must match uninterrupted execution exactly.
