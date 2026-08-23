# Thirty-Two-Node Grey-Box Transformer Ladder

This redistributable grey-box product executes a declared thirty-two-node physical R-L-C-G ladder between two external transformer terminals. Every branch owns its resistance and inductance, every represented node owns shunt capacitance and conductance, and internal nodes are condensed only for the external network solve while their accepted voltages and branch currents remain explicit outputs. The production path advances 1,000 fixed 10 µs steps at 100 Hz with a terminal fault at 5 ms.

## Run the example

Run `make run` in this directory. AIMORA solves the represented internal network, verifies internal KCL, captures a typed checkpoint at the midpoint, and requires exact replay through the final accepted state.

## Output artifacts and interpretation

`transformer_waveforms.csv` records the representative terminal waveform, power, energy, and network KCL. `transformer_waveforms.svg` visualizes the transient. `transformer_report.txt` records node-tier identity, internal KCL, energy, event, signatures, uncertainty, and unsupported quantities. `summary.md` states the public boundary.

This ladder is one generic physical realization, not a unique inference from terminal data. It makes no geometry-complete white-box, vendor, ATP/PSCAD-equivalence, protected-standard, insulation-design, lifetime, field-accuracy, or certification claim.
