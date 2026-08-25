# Extended Converter Systems

This public AIMORA-authored case exposes the complete released converter family/fidelity boundary and executes one inspectable switching-detailed physical workflow through the public Engine API and explicitly activated production backend.

The capability matrix contains every combination of the three released fidelity labels with all 22 standalone converter families and all five application compositions.
It marks 52 standalone and five application intersections executable and retains the 24 unsupported intersections as explicit refusals rather than silently substituting another family or fidelity.
The modulation column lists every public method admitted for the selected family.

The executable workflow is an original generic 120 V buck converter with a physical source impedance, series inductor, output capacitor and resistive load.
Its switching-detailed IGBT and diode retain nonlinear junction charge, diode recovered charge, turn-off tail current, switching-energy maps, snubbers and a two-stage passive thermal model.
An exact block/restart calendar exercises freewheeling and restart, while a portable mid-run snapshot proves exact continuation.
The runner checks typed acceptance, deterministic replay, KCL, charge, energy, nonnegative detailed state and event occurrence before writing artifacts.

## Run

Run `make run` from this directory in a workspace whose Julia environment explicitly activates the private production solver.
The public `AIMORA` package remains loadable without that backend and returns its typed unavailable result when production execution is requested without activation.

## Output artifacts

The committed `outputs/` directory contains:

- `converter_family_fidelity_matrix.csv`, the complete admitted/refused public boundary;
- `switching_detailed_buck_waveform.csv`, the physical electrical and detailed-device trace;
- `switching_detailed_buck_electrical.svg` and `switching_detailed_buck_device_state.svg`, curated inspectable plots;
- `converter_result_contract.csv`, the versioned typed result identity, residuals and deterministic signatures;
- `summary.md`, the exact case counts, limits and principal metrics.

The public case is intentionally small enough to inspect and rerun.
Complete execution of every admitted family/fidelity intersection and all five application compositions, independent formulations, OpenModelica overlap, adversarial mutations and P0–P2 scale evidence remain qualification products rather than duplicated public-case kernels.

This generic case does not claim manufacturer prediction, product design, arbitrary topology synthesis, destructive failure, renewable-plant, FACTS, HVDC or MMC behavior, ATP/PSCAD equivalence, protected-standard conformance, field validation, safety, HIL qualification or certification.
