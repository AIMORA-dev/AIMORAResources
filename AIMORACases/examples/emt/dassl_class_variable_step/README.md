# Optional DASSL-Class Variable-Step EMT

This redistributable Julia case demonstrates AIMORA's explicitly selected variable-step, variable-order implicit DAE mode without changing the fixed-step EMT default. It executes the same canonical public physical owners through the private production backend; the public package retains only solver selection, settings, readiness/refusal, result, diagnostics, and snapshot contracts.

The passive slice contains a finite Thevenin source and one series R-L-C branch. It publishes requested-grid dense output, KVL/charge/stored-energy checks, and exact portable split/restart identity. The nonlinear slice combines a capacitor, conductance, cubic current law, and an exact closing/opening resistance switch; left and right transition states prove that dense output does not cross either discontinuity. The machine slice executes the admitted wound-field electromagnetic flux, single-mass shaft, one source event, and two exact sampled-control releases. A separate ideal-transformer constraint proves typed readiness refusal for an owner outside the frozen admission matrix.

## Run

Set `AIMORA_SOLVER_PATH` to an authorized local `AIMORASolvers.jl` checkout, then run `make run`. `AIMORA_ENGINE_PATH` may identify a non-sibling public engine checkout. Neither path is written into the artifacts.

```text
AIMORA_ENGINE_PATH=/path/to/AIMORA.jl \
AIMORA_SOLVER_PATH=/authorized/path/to/AIMORASolvers.jl \
make run
```

The public engine loads without the private solver. Without an activated backend its DASSL preparation/readiness functions return `SolverUnavailableResult`; public package tests and the fresh-clone qualification own that solver-free check. The case is marked `requires_solver = true` because generating the accepted production waveforms requires the private backend.

## Outputs

`passive_dense_output.csv` and `.svg` show requested-grid passive voltages, current, and stored energy. `nonlinear_switching_output.csv` and `.svg` retain duplicate left/right rows at exact switch transitions. `machine_control_output.csv` and `.svg` show the admitted machine terminal and shaft response. `result_contract.csv` records readiness/state counts, work diagnostics, restart identities, deterministic result identities, and refusal disposition. `summary.md` records the principal checks and unsupported boundary.

All parameters are synthetic and redistributable. This example does not claim support for every EMT owner, arbitrary high-index DAEs, switch-detailed PWM, fixed-coefficient delayed histories, real-time/HIL, universal speedup, ATP/PSCAD/OpenModelica/DASSL equivalence, standards conformance, certification, or operating systems not executed by the qualification evidence.
