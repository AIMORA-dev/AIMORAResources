# Virtual-Synchronous Grid-Forming VSC

This public synthetic case executes the extended switching-detailed VSC with virtual inertia, damping, impedance and current filtering, a four-wire LCL filter and explicit neutral, exact sampled control and PWM, typed plant requests, unbalance and zero sequence, disturbances, commanded block/restart, and DC/AC energy accounting.

The converter uses the canonical B200 four-leg two-level topology, selected D200 device state, S210 task boundaries, I200-compatible initialization, and the private production nonlinear backend. Generic non-standard protection bounds keep the demonstration inside its declared voltage, current, and frequency domain while the swing equation, virtual impedance, voltage loop, and current limit remain fully active. Four-wire execution owns the neutral R-L branch and reports neutral current and its KCL closure explicitly.

## Run

Run `make run` in a private owner worktree with the production backend activated. The committed outputs include deterministic CSV data, current and DC/sequence SVG plots, and a scalar summary. The values are generic AIMORA-authored SI inputs with no manufacturer, grid-code, ATP/PSCAD, or certification claim.

## Output artifacts

Inspect `extended_vsc_virtual_synchronous_currents.svg` for phase and neutral response under negative and zero sequence, fault, DC sag, block/restart, island, and reconnection. Inspect `extended_vsc_virtual_synchronous_response.svg` for DC-link and sequence voltages. The `extended_vsc_virtual_synchronous.csv` table retains power, oscillator frequency, duty, mode, and request disposition. The summary should confirm finite output, exact task and event alignment, settled sequence extraction, neutral and nodal KCL below the declared tolerances, and relative physical energy residual below `1e-6`.
