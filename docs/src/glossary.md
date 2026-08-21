# Glossary

**Accepted evidence**
A result recorded in the project ledger after the exact requirement, implementation revision, registered validation, and publication boundaries pass.

**Availability**
Whether a study or capability is `implemented`, `planned`, `unavailable`, or retained only as a `legacy_reference`.

**Backend**
A numerical implementation of the public AIMORA solver contract. The production backend is separately governed and explicitly activated.

**Canonical project**
The revisioned physical system model containing shared asset identity, topology, ratings, parameters, provenance, profiles, and scenarios. It is not mutable solver state.

**Capability**
A typed backend declaration identifying a supported study, representation, fidelity, and version.

**Case**
A versioned public example input and executable consumer with documentation, outputs, and provenance.

**Checkpoint / snapshot**
A versioned complete state inventory sufficient to resume an admitted study deterministically.

**Companion model**
A discrete-time equivalent used to stamp dynamic components such as inductors and capacitors into the nodal equations.

**Content hash**
A SHA-256 digest of canonical semantic data. Report approvals and freezes bind this hash.

**Deck**
A readable or fixed-field electrical input document parsed into typed models. It is data, not source code.

**Dependency DAG**
The directed acyclic graph connecting a result to exact upstream results used by a downstream study or combined report.

**Deterministic build**
A build that produces identical declared artifacts from identical semantic input, template, toolchain, source date, and environment locks.

**Diagnostic**
A typed message with severity, code, component/source location, explanation, and blocking status.

**EMT**
Electromagnetic-transient simulation using instantaneous time-domain electrical quantities and explicit events.

**Event localization**
The process of locating a discontinuity or control/event boundary at the required temporal accuracy rather than accepting it at an arbitrary coarse sample.

**Fidelity**
The physical detail of a model, such as average-value, switching-detailed, state-equivalent, legacy-detailed, or field-coupled detailed.

**Frozen report**
An approved report whose semantic content is bound to an immutable hash. A correction creates a new revision.

**Gitlink**
A superproject record pinning an exact child-repository commit.

**KCL residual**
The current-balance residual at network nodes after solution and output reconstruction.

**Manifest**
A machine-readable inventory of report/source/toolchain/artifact identities and checksums.

**MNA**
Modified nodal analysis, including additional equations/unknowns for ideal sources or constraints.

**Passivity**
A property preventing a fitted network model from generating net energy under its declared conditions.

**Planned study**
A documented future contract that must refuse production execution until implemented and accepted.

**Provider**
A function that maps a typed study result and its limitations/evidence into a minimum useful semantic report. A provider does not recompute study physics.

**Qualification**
The evidence state of a capability: unqualified, prototype evidence, qualified, or production.

**Readiness**
A pre-execution check confirming that the project, parameters, model fidelity, solver capabilities, units, and settings are sufficient for the requested study.

**Renderer**
An optional adapter that converts semantic visual/report data into HTML, Markdown, TeX, PDF, SVG, CSV, JSON, or another declared format.

**Representation**
The mathematical view of a physical asset used by a study, such as instantaneous EMT, static phasor, dynamic phasor DAE, harmonic frequency domain, short circuit, thermal field, or protection measurement.

**Result binding**
The immutable identity/provenance link from a report or downstream study to an exact typed result.

**Revision**
A versioned project, result, report, template, or source state. Changing engineering meaning creates a new revision.

**Semantic report**
A renderer-independent typed document containing sections, equations, data tables, plots, diagnostics, provenance, review, and publication state.

**Source coverage**
The machine-checked mapping from public model/study/parser/case/report owners to canonical documentation.

**Study realization**
The explicit representation of a canonical physical asset for one study and fidelity.

**TACS**
Transient Analysis of Control Systems: control/signal blocks and sampled tasks coupled to admitted electrical components.

**Typed result**
A versioned result object with explicit quantities, units, bases, settings, provenance, assumptions, warnings, and hashes.

**Validity domain**
The operating, frequency, timestep, geometry, parameter, or evidence range over which a model/result claim is admitted.

**Visual specification**
Renderer-neutral axes, units, series, uncertainty, events, transforms, clipping, caption, and accessibility semantics.
