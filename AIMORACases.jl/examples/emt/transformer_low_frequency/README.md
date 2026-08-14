# Low-Frequency Terminal-Matrix Transformer

This redistributable generic product executes one explicitly selected coupled low-frequency transformer terminal matrix through AIMORA's production nonlinear nodal path. The model retains its complete resistance, leakage-inductance, terminal-capacitance, dielectric-conductance, and mutual-coupling matrices. It advances 1,000 fixed 10 µs steps at 100 Hz, applies one terminal fault at 5 ms through the apparatus event contract, accepts state only after network convergence, and repeats the second half from a typed midpoint checkpoint.

## Run the example

Run `make run` in this directory. The command uses the local public engine and the activated production backend, then regenerates the deterministic artifacts below `outputs/`. A successful completion reports 1,000 accepted steps and `restart_exact=true`.

## Output artifacts and interpretation

`transformer_waveforms.csv` records the first physical terminal voltage and inward current, terminal power, cumulative supplied energy, and network KCL residual. `transformer_waveforms.svg` is the curated visual trace; inspect the bounded response and the change at 5 ms. `transformer_report.txt` records tier identity, energy, residual, event, signature, uncertainty, and unsupported-output boundaries. `summary.md` gives the compact public result.

This terminal tier does not represent core-local flux or internal winding voltage. Synthetic values do not support ATP/PSCAD equivalence, vendor accuracy, protected-standard conformance, lifetime, insulation design, or certification.
