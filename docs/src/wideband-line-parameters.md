# Wideband Line Parameters

AIMORA prepares coupled phase-domain series impedance ``Z(f)`` in ohm per metre and shunt admittance ``Y(f)`` in siemens per metre on an explicit, strictly increasing frequency grid. The result is parameter data for later line-model selection; it is not a rational fit, propagation model, convolution history, or time-domain line realization.

## Inputs and conventions

An overhead segment owns round-conductor or bundle-equivalent geometry above a flat earth, conductor resistance and radius, length, phase order, soil profile, source identity, rights, and validity. A cable segment owns admitted round-conductor geometry, burial coordinates, dielectric properties, conductor material options, grounded-conductor reduction policy, length, phase order, soil, and the same source metadata. Inputs are SI, frequency is in hertz, matrices are complex symmetric in the reciprocal domain, and every route phase has an explicit symbolic identity.

The released soil owner accepts one homogeneous half-space or two through four horizontal, isotropic layers terminated by a half-space. Each finite layer declares positive thickness, resistivity, relative permittivity, and relative permeability. Anisotropy, frequency-dependent measured soil, terrain, ionization, seasonal inference, and general field solving are outside this release.

## Equations and assembly

Overhead electrostatic coefficients use the direct-conductor and image-conductor distances. In compact form, ``P_ii = \log(2 h_i/r_i)/(2\pi\epsilon_0)`` and ``P_ij = \log(D'_{ij}/D_{ij})/(2\pi\epsilon_0)``. Matrix inversion gives the electrostatic capacitance, and ``Y(f) = j 2\pi f C`` for the lossless public dielectric slice. Series impedance combines the existing conductor/internal and external-inductance owners with homogeneous-earth return or the released layered-earth spectral surface-admittance recursion.

Cable assembly uses the existing nested geometry, internal impedance, electrostatic admittance, earth-return, and explicit grounded-conductor Schur-complement owners. The public ideal coaxial dielectric limit is ``C' = 2\pi\epsilon/\log(r_o/r_i)``. No diagonal or sequence approximation replaces the coupled conductor and phase matrices.

For route segments ``s`` expressed in a common phase basis, AIMORA applies the declared phase permutation on both matrix axes and forms ``Z_route(f) = \sum_s \ell_s P_s Z_s(f) P_s^T`` and the corresponding sum for ``Y``. Per-metre route averages divide these totals by the complete positive route length. This length-weighted parameter composition is not a cascaded propagation solution.

## Provenance, uncertainty, and interchange

Every segment records physical-parameter provenance, units, transformation, uncertainty statement, validity domain, rights, data class, and a SHA-256 content identity. Native input and every complete parameter set have deterministic signatures. Uncertainty envelopes compare explicitly supplied alternative complete parameter sets in the same phase basis and frequency grid and retain componentwise absolute radii plus maximum relative changes; they do not silently invent statistical distributions.

`write_line_parameter_set` writes the versioned TOML interchange form, and `read_line_parameter_set` validates schema, dimensions, phase order, frequency order, source records, and the deterministic signature before returning a complete immutable result. Unknown schemas, malformed complex matrices, missing provenance, incompatible bases or grids, nonfinite values, and signature changes are refused.

## Diagnostics and reports

The result reports symmetry error, the smallest Hermitian loss eigenvalue, condition number, layered-earth quadrature error, route length, phase basis, sources, warnings, and deterministic identity at every frequency. Physical acceptance requires finite matrices, reciprocal symmetry, and no negative passive loss beyond the published numerical floor. A large condition number or uncertainty envelope remains visible even when the basic physical checks pass.

The public examples `line_parameters_overhead`, `line_parameters_cable`, and `line_parameters_mixed_route` write a text report, versioned TOML data, a 60 Hz phase-matrix CSV, a frequency-scan CSV, and one curated SVG. The generic catalogue entry is `generic_wideband_line_parameter_inputs`.

## Evidence and limits

Independent Julia equations cover overhead potential coefficients, ideal coaxial admittance, conductor reduction, phase-mapped route sums, and deterministic uncertainty radii without reusing production assembly or report code. External comparisons are meaningful only for the exact geometry, conductor, soil, units, frequency, and reduction overlap reported by that tool; they do not establish equivalence to ATP, PSCAD, protected standards, vendor models, field measurements, or certification.

Rational fitting, fitted-model passivity enforcement, modal tracking, propagation delays, time-domain histories, switching execution, adaptive/DASSL integration, anisotropic or ionized soil, general cable field solving, transposition schedules beyond an explicit admitted phase mapping, and manufacturer prediction are not claimed here.
