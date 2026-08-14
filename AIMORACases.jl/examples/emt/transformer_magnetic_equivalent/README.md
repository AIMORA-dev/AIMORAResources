# Magnetic-Equivalent-Circuit Transformer

This redistributable product executes one unified magnetic-equivalent-circuit transformer with explicit electrical windings, leakage matrices, terminal capacitance, dielectric conductance, magnetic continuity, winding turns, branch geometry, and a nonlinear piecewise material law. AIMORA advances the coupled algebraic and accepted magnetic state through the production nonlinear nodal path for 1,000 fixed 10 µs steps at 100 Hz. A terminal fault is localized at 5 ms and the second half is replayed from a typed midpoint checkpoint.

## Run the example

Run `make run` from this directory. The backend must report 1,000 accepted steps and exact checkpoint continuation; any nonconvergence, active energy, or topology mismatch fails the command.

## Output artifacts and interpretation

`transformer_waveforms.csv` contains terminal response, power, supplied energy, and KCL evidence. `transformer_waveforms.svg` shows the event-sensitive trajectory. `transformer_report.txt` records magnetic residuals, energy balance, event count, exact signatures, provenance, uncertainty, and absent quantities. `summary.md` provides the compact interpretation.

The declared generic magnetic graph is not a field-solved core, vendor design, protected-standard specimen, thermal-aging model, or certification calculation. It establishes no ATP/PSCAD equivalence, manufacturer prediction, insulation coordination, or lifetime claim.
