# Mixed Overhead/Cable Route Parameters

This generic case combines an overhead segment and a phase-permuted cable segment over a two-layer soil profile. The output is a route-integrated parameter summary after exact phase-basis mapping; it is not a propagation, transition-joint, rational-fit, or time-domain line model.

The route contains 750 m of the public three-phase overhead geometry followed by 250 m of the public three-single-core cable geometry. Both use one explicit two-layer isotropic soil profile: a finite 100 ohm-metre upper layer over a 300 ohm-metre half-space. The cable declares the order `phase_c`, `phase_a`, `phase_b`; route assembly maps both matrix axes back to the common phase basis before applying the length-weighted sum at 10, 60, 600, and 6000 Hz.

## Run

From this directory, run `make run`, or select `line_parameters_mixed_route` through the Resources example runner. The private production backend must be installed beside the public engine so the established line and cable physics owners can be activated without placing solver source in this public repository.

## Output artifacts

Inspect `line_parameter_report.txt` and `line_parameters.toml` for segment identities, phase orders, soil signatures, route length, diagnostics, and deterministic identity. `series_impedance_60hz.csv` shows the integrated average phase matrix; `frequency_scan.csv` and `frequency_scan.svg` show self and mutual impedance magnitudes. The result should confirm that phase mapping changes indexing without losing reciprocity or passive loss. The length-weighted route total does not model junction fields, reflections, modal propagation, rational fitting, EMT histories, manufacturer behavior, ATP/PSCAD equivalence, or certification.
