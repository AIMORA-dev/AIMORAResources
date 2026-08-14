# Four-Winding Sectioned White-Box Transformer

This generic white-box product executes four explicitly ordered windings with eight geometry-owned sections per winding. Every section retains complete mutual series resistance and inductance plus shunt conductance and capacitance matrices, declared section length, winding incidence, geometry hash, response band, and mesh-refinement residual. AIMORA advances the represented internal node voltages, branch currents, charge, energy, and external terminal response through the production nonlinear nodal path for 1,000 fixed 10 µs steps at 100 Hz.

## Run the example

Run `make run` here. The execution applies one terminal fault at 5 ms, verifies internal KCL and passive energy, captures the exact midpoint checkpoint, and requires bitwise-identical continuation.

## Output artifacts and interpretation

`transformer_waveforms.csv` records representative terminal voltage/current, total power, supplied energy, and KCL. `transformer_waveforms.svg` displays the transient. `transformer_report.txt` records winding/terminal counts, represented-network residual, energy, event, exact signatures, uncertainty, and unavailable outputs. `summary.md` states how to interpret the result.

The synthetic section data are not a field solution, protected standard, vendor winding, thermal-aging model, insulation-design result, or certification calculation. They do not prove ATP/PSCAD equivalence, manufacturer accuracy, lifetime, or safe extrapolation beyond the declared band and mesh.
