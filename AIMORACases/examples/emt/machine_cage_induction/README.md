# Cage Induction Machine

This redistributable generic product executes a three-phase, explicit-neutral single-cage induction motor with rotor electrical state, slip, shaft state, a source-unbalance and torque event, energy diagnostics, and exact checkpoint continuation.

## Model and limits

The example uses synthetic SI parameters and a fixed electromagnetic timestep. Positive terminal current and electrical power enter the machine; positive shaft torque accelerates the declared mechanical direction. The cage state is dynamic, so this is not a prescribed-speed or scalar steady-slip calculation. The parameters establish no vendor, standard, field, protection, thermal, ATP/PSCAD, HIL, or certification equivalence.

## Run

Run `make run` from this directory, or execute `julia --project=../.. run.jl` through the configured AIMORA workspace. The runner reconstructs the deterministic input, executes the event and split restart, and rewrites the public artifacts.

## Outputs

- `machine_waveforms.csv` contains time, terminal electrical quantities, rotor speed, slip, torque, power, energy, and residual diagnostics.
- `machine_report.txt` and `summary.md` record the selected family, state, event, restart, and declared limits.
- `machine_waveforms.svg` and `machine_mechanical.svg` provide curated electrical and mechanical views.

## Interpretation

Inspect the waveform plot for the applied unbalance and the mechanical plot for the torque-event response. Slip should change continuously with shaft speed, dissipative rotor behavior must remain passive, energy and KCL diagnostics should remain within the reported bounds, and the restarted trajectory must exactly match uninterrupted execution.
