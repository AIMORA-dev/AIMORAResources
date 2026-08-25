# Generic Fixed-Step Protection Products

This public example executes five AIMORA-authored protection products through the canonical typed preparation, exact seven-stage protection task pipeline, public relay-element and logic owners, deterministic communication where declared, and a real three-pole fixed-step breaker connected to an EMT nodal network.

The products cover radial phase/residual overcurrent with failure/reclose ownership, directional-distance line protection with an admitted incremental wave and permissive message, transformer/bus biased differential, machine/converter frequency-ROCOF, and DC differential/overcurrent logic. Each CSV and SVG exposes element assertion, trip command, physical contact state, and load-voltage collapse after the actual breaker contacts open. The summaries bind exact product and preparation signatures.

All settings and waveforms are synthetic, generic, nonvendor, noncoordinated, nonmeasured, and noncertifying. The example does not claim a protected standard, IEC 61850 or telecom protocol, field timing, vendor behavior, physical HIL, detailed SF6/vacuum arc physics, ATP/PSCAD equivalence, safety integrity, or certification.

Each product writes a canonical public `.aimora` runtime snapshot, inspects it without the private solver, restores a freshly prepared runtime, and requires exact deterministic state identity. The `controller/aimora_protection_controller.c` fixture implements the same generic 8 A pickup and 7.2 A dropout contract through the accepted P210 shared-library ABI. The run compiles it in a temporary directory, verifies its exact library hash, compares every pickup and trip output with the Julia relay state, restores both implementations at the same sample, and proves identical continuation. No compiled library is committed.

## Run

Run `make run` from this directory in an AIMORA workspace whose Julia environment explicitly activates the production solver backend and provides a C compiler for the optional loopback fixture.
The runner builds the temporary shared library outside the repository, executes all five public products, verifies exact snapshot continuation, and writes only reviewed portable artifacts below `outputs/`.

## Output artifacts

Each named product commits a CSV trace, curated SVG, portable `.aimora` snapshot, and scalar Markdown summary.
`protection_logic.svg` compares the five typed logic/contact sequences, while `protection_c_loopback.csv` and its summary record exact Julia/C pickup, dropout, trip and restored-continuation agreement.
