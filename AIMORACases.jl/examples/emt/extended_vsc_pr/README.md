# Stationary PR Grid-Following VSC

This public synthetic case executes the extended switching-detailed VSC with a stationary-frame proportional-resonant controller, selected harmonic resonators, a three-wire shunt-LC filter, exact sampled control and PWM, typed plant requests, disturbances, commanded block/restart, sequence extraction, and DC/AC energy accounting.

The case uses a bounded generic active-power request, passive shunt damping, and explicit first, fifth, and seventh harmonic resonator state. It composes the canonical B200 two-level bridge, selected D200 device state, S210 task boundaries, I200-compatible initialization, and the private production nonlinear backend. Current is positive from converter to grid and active power is positive from DC to AC. No average-value converter or hidden settling model substitutes for the switching network.

## Run

Run `make run` in a private owner worktree with the production backend activated. The committed outputs include deterministic CSV data, current and DC/sequence SVG plots, and a scalar summary. The values are generic AIMORA-authored SI inputs with no manufacturer, grid-code, ATP/PSCAD, or certification claim.

## Output artifacts

Inspect `extended_vsc_pr_currents.svg` for the three-wire response of the damped LC network through the scheduled disturbances and block/restart. Inspect `extended_vsc_pr_response.svg` for DC-link voltage and extracted sequence content. The `extended_vsc_pr.csv` table also records power, controller frequency, duty, operating mode, and plant-request disposition. The summary should confirm finite output, exact task and event alignment, settled sequence extraction, KCL below the declared tolerances, and relative physical energy residual below `1e-6`. These results qualify only the exact public PR, LC, device, and parameter combination.
