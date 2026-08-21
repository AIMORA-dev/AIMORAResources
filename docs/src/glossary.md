# Glossary

**Acceptance criterion** — A predefined quantitative or logical condition that a run, model, case, or comparison must satisfy before it is accepted.

**Algebraic state** — A variable solved from instantaneous constraints rather than integrated through time.

**Average-value model** — A converter representation that averages switching behavior over a carrier interval and omits explicit semiconductor commutations.

**Base quantity** — Reference voltage, current, power, impedance, speed, or other value used to interpret a per-unit quantity.

**BCTRAN-style model** — A transformer terminal representation based on test-derived multiwinding matrices. The term describes a modeling style, not certification against another product.

**Bergeron model** — A travelling-wave line representation using characteristic impedance/admittance and delayed terminal history.

**Capability descriptor** — Typed record identifying a study, domain, maturity, and source owner.

**Case** — A reproducible engineering example containing purpose, input, entrypoint, output contract, interpretation, and acceptance evidence.

**Checkpoint** — Serialized execution state sufficient to resume a run under a compatible model/solver/schema contract.

**Companion model** — A discrete-time equivalent of a dynamic component, typically represented by an instantaneous conductance/admittance plus history source.

**Constitutive law** — Mathematical relationship between physical quantities of a component, such as nonlinear current as a function of voltage.

**Control calendar** — Exact release schedule for sensing, estimation, control, modulation, protection, or reporting tasks.

**Deck** — Text input containing typed or classic fixed-field cards that define a study, topology, models, events, and outputs.

**Delayed history** — Stored past values required by travelling-wave, rational, sampled, or delayed-control models.

**Deterministic replay** — Re-execution that produces the same declared result according to a bitwise or tolerance-based contract.

**Direct feedthrough** — Output dependence on an input at the same logical instant, important for algebraic-loop analysis.

**EMT** — Electromagnetic transient time-domain study resolving instantaneous electrical quantities and fast events.

**Event localization** — Determination of the actual discontinuity time between or on integration steps.

**Fidelity** — Level and kind of physical/numerical detail represented by a model.

**Fixed-field card** — Input record whose meaning depends on exact character-column positions.

**Flux linkage** — Magnetic flux linked with a winding, often a dynamic state in machine/transformer models.

**Ground return** — Frequency-dependent current-return behavior through earth included in line/cable impedance calculations.

**Grey-box model** — Model combining known physical structure with identified parameters.

**History source** — Equivalent source representing accumulated dynamic state in a companion formulation.

**Implemented** — Maturity status indicating a callable study path exists for a declared validity domain.

**KCL residual** — Numerical imbalance of currents at a solved node according to Kirchhoff’s current law.

**Legacy reference** — Historical implementation or evidence retained for comparison, not the production execution path.

**Modal transformation** — Mapping between phase/conductor quantities and decoupled or approximately decoupled modal quantities.

**Model contract** — Stable statement of inputs, outputs, state, validity, assumptions, maturity, update order, and evidence.

**Multi-mass shaft** — Mechanical model with multiple inertias connected by stiffness and damping.

**Multirate task** — Task executing on its own exact sample/release calendar while coupled to the electrical simulation.

**Nodal assembly** — Construction of network equations from model contributions and source/history injections.

**Not implemented** — Typed result status for a declared study that lacks a production numerical path.

**Passivity** — Property that a model cannot generate net energy internally under its declared port convention.

**Passivity correction** — Transformation of a fitted model to remove passive-behavior violations while controlling approximation error.

**Per unit (pu)** — Normalized quantity divided by a declared base.

**Phase domain** — Representation directly in physical phase/conductor coordinates rather than sequence or modal coordinates.

**Planned** — Maturity status for a roadmap/API descriptor without a production implementation.

**Pole/residue model** — Rational representation expressed through poles and residues, often converted to state space for runtime.

**Positive-real** — Frequency-domain property related to passivity for impedance/admittance models under appropriate assumptions.

**Prototype** — Experimental capability whose interface, behavior, or qualification may change.

**Provenance** — Traceable source, transformation, uncertainty, and revision of engineering data or evidence.

**Rational fitting** — Approximation of sampled frequency behavior by stable rational functions.

**Reference-compatible case** — Case that can run through a declared historical/reference path for comparison; this does not make the reference the production solver.

**Result contract** — Stable definition of status, quantities, units, assumptions, warnings, metadata, and acceptance evidence.

**Rollback** — Restoration of all mutated execution state after rejected work or event localization.

**Sequence component** — Positive-, negative-, or zero-sequence quantity derived through a specified transformation.

**Solver backend** — Numerical implementation registered behind the public scientific model/study contract.

**Source owner** — Logical source unit responsible for a model, study, parser, or interface declaration.

**State-space realization** — Dynamic representation using state, input, output, and feedthrough matrices.

**Study descriptor** — Typed catalog entry with ID, name, domain, maturity, and source owner.

**Surge impedance** — Characteristic voltage/current ratio of a travelling-wave mode or line under the declared convention.

**TACS** — Control-system style algebraic/dynamic signal composition used with electrical simulation.

**Task release** — Exact instant when a sampled/multirate task executes.

**Terminal order** — Documented ordering of ports, windings, phases, or conductors in vectors and matrices.

**Thevenin equivalent** — Ideal voltage source behind finite impedance representing a network boundary.

**Topology event** — Change in electrical connectivity caused by a switch, fault, breaker, or controlled device.

**Typed quantity** — Value accompanied by a stable key, unit, optional base, and description.

**Validity domain** — Declared physical/numerical/fidelity bounds within which a model is supported.

**Vector fitting** — Iterative method for fitting rational functions to sampled frequency responses.

**White-box model** — Model derived primarily from detailed geometry, materials, and internal physical structure.

**Wideband model** — Frequency-dependent dynamic model intended to reproduce behavior over a broad declared frequency range.
