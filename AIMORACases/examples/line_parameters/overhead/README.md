# Wideband Overhead-Line Parameters

This AIMORA-authored generic case derives coupled phase-domain `Z(f)` and `Y(f)` for a three-phase overhead segment over homogeneous soil. It writes a typed interchange file, deterministic report, matrix CSV, frequency CSV, and SVG. The case is an engineering example, not utility, vendor, standard, ATP, or PSCAD validation.

The input uses three round bundle-equivalent phase conductors at a common height, explicit horizontal spacing, four subconductors per phase, generic conductor resistance and radius, a 1 km route length, and 100 ohm-metre homogeneous isotropic soil. Frequencies are 10, 60, 600, and 6000 Hz. All geometry and matrices use SI units and the declared `phase_a`, `phase_b`, `phase_c` basis.

## Run

From this directory, run `make run`. From the Resources root, the exact example runner can also select `line_parameters_overhead`. The private production backend must be installed beside the public engine because the existing full line-physics module is activated explicitly at runtime.

## Output artifacts

Inspect `line_parameter_report.txt` for route identity, sources, physical checks, and complex matrices; `line_parameters.toml` for the versioned deterministic interchange; `series_impedance_60hz.csv` for the phase matrix; and `frequency_scan.csv` plus `frequency_scan.svg` for self and mutual series-impedance magnitudes. Symmetry, finite condition numbers, nonnegative loss within the numerical floor, and the deterministic signature should remain stable. The plot illustrates frequency dependence only; it does not prove propagation, fitting, field-measurement agreement, or certification.
