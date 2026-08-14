# Hybrid Leakage and Nonlinear-Core Transformer

This generic public product combines complete terminal leakage, winding resistance, capacitance, dielectric loss, and mutual coupling with one explicitly connected nonlinear magnetic graph. The two core branches use a sourced piecewise-linear material curve and explicit winding turns. AIMORA solves the electrical and magnetic endpoint together through the production nonlinear nodal transaction for 1,000 fixed 10 µs steps at 100 Hz, including one terminal-fault topology event at 5 ms and accepted-state rollback discipline.

## Run the example

Run `make run` in this folder. The production backend executes the coupled Jacobian and repeats the second half from a typed midpoint checkpoint. A passing run prints 1,000 accepted steps and exact restart confirmation.

## Output artifacts and interpretation

`transformer_waveforms.csv` records terminal voltage/current, power, supplied energy, and KCL. `transformer_waveforms.svg` lets you inspect the nonlinear event response. `transformer_report.txt` includes magnetic-continuity, energy, event, deterministic-signature, provenance, uncertainty, and unsupported-output fields. `summary.md` states the narrowed claim.

The synthetic curve is not a vendor steel, field measurement, protected standard, thermal model, insulation design, or lifetime model. Results do not claim ATP/PSCAD equivalence, manufacturer prediction, standard conformance, or certification.
