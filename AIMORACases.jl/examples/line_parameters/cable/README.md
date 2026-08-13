# Wideband Cable Parameters

This generic case derives coupled phase-domain `Z(f)` and `Y(f)` for three single-core buried cables with explicit dielectric and soil data. It demonstrates typed provenance, physical diagnostics, deterministic interchange, and public plots without claiming a manufacturer construction.

The synthetic input places three round cable conductors at equal depth with explicit horizontal spacing, conductor radius, and relative dielectric permittivity. It uses a 500 m length, 100 ohm-metre homogeneous isotropic soil, frequencies of 10, 60, 600, and 6000 Hz, and the declared `phase_a`, `phase_b`, `phase_c` basis. The existing cable geometry, internal impedance, electrostatic admittance, and earth-return owners supply the coupled matrices in SI units.

## Run

From this directory, run `make run`. The Resources example runner can instead select `line_parameters_cable`. The private production backend must be available beside the public engine because this public case explicitly activates the existing full line-physics module; no private source is copied into the case.

## Output artifacts

Inspect `line_parameter_report.txt` for complete matrix and diagnostic text, `line_parameters.toml` for versioned interchange and provenance, `series_impedance_60hz.csv` for the coupled phase matrix, and `frequency_scan.csv` with `frequency_scan.svg` for the self and mutual impedance trends. The result should confirm reciprocal symmetry, finite quantities, passive loss within the published floor, and deterministic replay. It does not represent a vendor cable, arbitrary sheath/armor construction, rational fit, time-domain propagation model, field measurement, or standards certification.
