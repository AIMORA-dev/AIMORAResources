# Synchronous PLL-dq Grid-Following VSC

This public synthetic case executes the extended switching-detailed VSC with a synchronous-reference-frame PLL and current controller, a three-wire series-L filter, exact sampled control and PWM, typed plant requests, disturbances, commanded block/restart, sequence extraction, and DC/AC energy accounting.

The case uses the canonical B200 two-level bridge, selected D200 device state, S210 task boundaries, I200-compatible initialization, and the private production nonlinear backend. Current is positive from converter to grid and active power is positive from DC to AC. The PLL estimates the positive-sequence angle and frequency; the dq loop maps the typed plant power request into a bounded current reference and applies explicit voltage limiting and anti-windup.

## Run

Run `make run` in a private owner worktree with the production backend activated. The committed outputs include deterministic CSV data, current and DC/sequence SVG plots, and a scalar summary. The values are generic AIMORA-authored SI inputs with no manufacturer, grid-code, ATP/PSCAD, or certification claim.

## Output artifacts

Inspect `extended_vsc_pll_dq_currents.svg` for the three-wire grid-current response through the sag, fault, block/restart, DC sag, island, and reconnection sequence. Inspect `extended_vsc_pll_dq_response.svg` for DC-link voltage and extracted positive, negative, and zero sequences. The `extended_vsc_pll_dq.csv` table retains the corresponding typed waveform columns, controller frequency, duty, mode, and request disposition. The summary should confirm finite output, exact task and event alignment, settled sequence extraction, KCL below the declared tolerances, and relative physical energy residual below `1e-6`.
