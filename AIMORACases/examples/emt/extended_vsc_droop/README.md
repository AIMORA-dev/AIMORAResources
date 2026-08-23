# Power-Droop Grid-Forming VSC

This public synthetic case executes the extended switching-detailed VSC with active-power/frequency and reactive-power/voltage droop, a four-wire LCL filter and explicit neutral, exact sampled control and PWM, typed plant requests, unbalance and zero sequence, disturbances, commanded block/restart, and DC/AC energy accounting.

The converter uses the canonical B200 four-leg two-level topology, selected D200 device state, S210 task boundaries, I200-compatible initialization, and the private production nonlinear backend. The grid-forming controller owns filtered power, oscillator angle and frequency, voltage-loop state, current limiting, anti-windup, and virtual impedance state. Four-wire execution owns the neutral R-L branch and reports neutral current and its KCL closure explicitly.

## Run

Run `make run` in a private owner worktree with the production backend activated. The committed outputs include deterministic CSV data, current and DC/sequence SVG plots, and a scalar summary. The values are generic AIMORA-authored SI inputs with no manufacturer, grid-code, ATP/PSCAD, or certification claim.

## Output artifacts

Inspect `extended_vsc_droop_currents.svg` for phase and neutral response under negative and zero sequence, source harmonics, fault, block/restart, DC sag, island, and reconnection. Inspect `extended_vsc_droop_response.svg` for DC-link and sequence voltages. The `extended_vsc_droop.csv` table retains power, controller frequency, duty, operating mode, and request disposition. The summary should confirm finite output, exact task and event alignment, settled sequence extraction, neutral and nodal KCL below the declared tolerances, and relative physical energy residual below `1e-6`.
