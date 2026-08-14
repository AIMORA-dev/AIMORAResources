# Passive Wideband Black-Box Transformer

This generic product executes a passive twelve-port, twenty-four-state transformer realization over its declared 10 Hz–40 kHz response band. The stable real state matrix, explicit input/output maps, direct admittance, storage matrix, passivity margin, port order, and response hash are immutable preparation data. AIMORA advances the actual rational state through the production nonlinear nodal path for 1,000 fixed 10 µs steps at 100 Hz and applies one terminal-fault event at 5 ms.

## Run the example

Run `make run` here. The command solves all twelve ports, captures a typed midpoint checkpoint, repeats the second half, and requires a bitwise-identical final public result signature.

## Output artifacts and interpretation

`transformer_waveforms.csv` records representative terminal voltage/current, total terminal power, energy, and KCL. `transformer_waveforms.svg` shows the bounded response and event. `transformer_report.txt` identifies the wideband tier, ports, passive energy, signatures, uncertainty, and unavailable internal quantities. `summary.md` explains the limit.

A black-box response owns external ports only. It cannot establish core flux, internal winding voltage, geometry, manufacturer behavior, protected-standard compliance, ATP/PSCAD equivalence, insulation stress, lifetime, or certification.
