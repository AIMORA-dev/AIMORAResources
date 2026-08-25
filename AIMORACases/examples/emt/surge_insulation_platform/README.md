# Generic Surge and Insulation Platform

This public example executes five AIMORA-authored products: three-pole arc interruption with vacuum chopping and restrike state, a metal-oxide-arrester-protected apparatus terminal, a direct-strike tower/line/ionizing-ground/backflash path, a GIS/GIL terminal with dynamic corona and leader state, and a seeded statistical insulation study.

The first four products use the private production backend only for the canonical nonlinear nodal solve while every model, product specification, readiness contract, result quantity, CSV, and SVG remains public. The statistical product uses a preregistered deterministic seed and reports its empirical failure probability with a Wilson confidence interval. All branch currents, power, lightning injection, ground current, and terminal stresses retain explicit SI peak orientation.

All parameters are synthetic and generic. These examples do not establish manufacturer or utility behavior, grounding safety, insulation design or lifetime, protected-standard conformance, field or laboratory agreement, ATP/PSCAD equivalence, safety integrity, or certification.

## Run

Run `make run` from this directory in an AIMORA workspace whose Julia environment explicitly activates the production solver backend.
The runner executes the five fixed synthetic products and regenerates their reviewed output directory without requiring a graphical session.

## Output artifacts

The committed `outputs/` directory contains separate `.csv` and curated `.svg` products for interruption/restrike, arrester terminal stress, tower backflash, GIS corona and seeded insulation statistics, plus one scalar `summary.md` binding the principal physical and deterministic results.
Inspect each voltage/current plot at its declared event boundary: interruption should expose chopping and any accepted restrike, the arrester and ground traces should absorb rather than create energy, tower and GIS stress should remain finite, and the statistical figure should agree with the seeded count and reported Wilson interval.
