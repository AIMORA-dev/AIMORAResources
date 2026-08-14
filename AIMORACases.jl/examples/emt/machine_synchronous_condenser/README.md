# Synchronous Condenser

This redistributable generic product executes a wound-field synchronous condenser with field and damper circuits, excitation task and limits, phase unbalance, a voltage-reference event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The synthetic SI parameters define stator, field and damper circuits, shaft state, sampled excitation, limiter state, and a fixed electromagnetic timestep. Positive terminal power enters the machine and reactive-power sign follows the report contract. This is a rotating machine var-support mode, not a static-var fallback or prescribed current source. The data establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner applies the voltage-reference event, verifies split restart, and rewrites all artifacts.

## Outputs

- `machine_waveforms.csv` records phase, field, excitation, speed, torque, active/reactive power, energy, event, and residual quantities.
- `machine_report.txt` and `summary.md` state operating mode, task timing, restart, and public limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` show electrical and mechanical response.

## Interpretation

The voltage-reference event should change excitation and reactive support only through the declared sampled task and limits. Inspect that speed and torque remain physically bounded, active/reactive power signs are consistent, energy and KCL diagnostics stay within reported bounds, and the restored trajectory exactly matches uninterrupted electrical, field, control, and shaft state.
