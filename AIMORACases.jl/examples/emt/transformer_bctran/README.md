# BCTRAN-Style Multiwinding Transformer

This redistributable product executes a generic three-phase, three-winding BCTRAN-style terminal representation. Nine ordered physical terminals retain complete symmetric resistance, leakage-inductance, shunt, and mutual-coupling matrices reconstructed with explicitly zero declared pair-test residuals. The production nonlinear nodal path advances 1,000 fixed 10 µs steps at 100 Hz and applies a terminal fault at 5 ms through the stable apparatus event order. No lower-fidelity scalar or ideal-transformer substitute is used.

## Run the example

Run `make run` here. AIMORA activates the production backend, solves every terminal simultaneously, and repeats the second half from the exact midpoint checkpoint. Completion must report 1,000 accepted steps and `restart_exact=true`.

## Output artifacts and interpretation

`transformer_waveforms.csv` contains terminal voltage/current, terminal power, energy, and KCL columns. `transformer_waveforms.svg` shows the bounded terminal trajectory and the event response. `transformer_report.txt` records reconstruction-tier identity, terminal count, energy balance, residuals, signatures, uncertainty, and unavailable quantities. `summary.md` states the public validity boundary.

BCTRAN terminal matrices do not establish core-local flux, internal section voltage, manufacturer behavior, or a unique physical interior. The synthetic product makes no ATP/PSCAD-equivalence, protected-standard, insulation-design, lifetime, field-accuracy, or certification claim.
