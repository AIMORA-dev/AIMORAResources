# Consistent EMT Initialization

AIMORA initializes an EMT study by solving a declared harmonic equilibrium, constructing every model-owned continuous, discrete, delayed-history, scheduler, output, energy, and checkpoint state required before the first advance, and probing the resulting state through the same timestep path used by the study. Initialization is atomic: an accepted result contains a prepared study and a complete report, while a refused result contains a typed failure and no mutable prepared study.

## Harmonic formulations

For physical frequency \(f\), AIMORA assembles the complex nodal equation

```math
\boldsymbol{Y}(j\omega)\,\underline{\boldsymbol{V}}=\underline{\boldsymbol{I}},\qquad \omega=2\pi f.
```

This formulation preserves the physical steady-state impedances. For a trapezoidal EMT timestep \(h\), the timestep-matched formulation instead evaluates reactive elements at the bilinear-transform frequency

```math
\omega_h=\frac{2}{h}\tan\!\left(\frac{\omega h}{2}\right).
```

The timestep-matched phasors seed the exact discrete companion recurrence, whereas the physical-frequency phasors preserve the continuous-frequency network. Their difference at finite \(h\) is expected and converges to zero under timestep refinement; selecting one formulation never relabels the other or silently settles the network through a hidden pre-simulation.

An initialization request declares the fundamental frequency in hertz, an optional scan grid in hertz, the formulation and timestep in seconds, the time origin in seconds, quantity-specific tolerances, and project, settings, and model signatures. Frequency scans report physical and reactive angular frequencies, complex peak node-to-ground phasors in volts, source injections in amperes, topology classification, rank, condition estimate, residual, symmetry error, dissipative eigenvalue, and acceptance for every point.

## Topology and numerical refusal

Before a state is admitted, AIMORA groups nodes joined by closed ideal constraints, finds connected components, classifies their voltage references, solves the reduced complex system, and checks numerical rank, conditioning, residual, reciprocity, and dissipative passivity. A unique referenced solution is required; islanded, inconsistent, rank-deficient, ill-conditioned, stale-signature, unknown-unit, unsupported-state, infeasible-model-state, and excessive-artificial-transient conditions return named failures rather than minimum-norm guesses or partially mutated runtime state.

The no-artificial-transient probe advances the prepared runtime through the production recurrence and measures scaled discontinuity, normalized RMS departure, and low-frequency envelope drift against quantity-specific tolerances. Model owners add their own residuals and inventory records, including network voltage, source state, R-L and R-C companion histories, fitted-line histories, switch modes, nonlinear magnetic histories, machine or converter states, control and scheduler state, energy accumulators, output cursors, topology state, and checkpoint continuation state when present.

## Typed operating-point mapping

An imported `OperatingPointQuantity` identifies its asset, quantity, phase, complex source value, unit, basis, orientation, uncertainty, and physical provenance. An `EMTOperatingPoint` additionally identifies its source representation, frequency, project/settings/model signatures, and—when it comes from a previous accepted EMT case—the exact deterministic source-state signature. AIMORA converts admitted quantities to SI, applies them as explicit harmonic constraints, reports the converted value, residual, uncertainty, and constraint reaction current, and refuses stale or physically inconsistent mappings.

The deterministic accepted-state signature covers the declared request and the complete prepared scientific state, including mutable histories, topology and event state, scheduler cursors, output state, matrices, factor workspaces, and checkpoint continuation data. It is an identity and replay guard, not a substitute for the physical and numerical checks in the report.

## Julia workflow

Construct a request with a declared formulation and signatures, then inspect the typed result before creating a workspace:

```julia
using AIMORA
using AIMORA.DeckParser
using AIMORA.EMTStudy

h = 500e-6
parsed = parse_deck_lines(readlines("network.deck"); source="network.deck")
request = EMTInitializationRequest(
    TimestepMatchedFormulation(h);
    frequency_hz=50.0,
    frequency_grid_hz=[10.0, 50.0, 70.0],
    project_signature="project-revision",
    settings_signature="emt-settings-revision",
    model_signature="network-model-revision",
)
result = initialize_emt_study(parsed, request; t_end_s=2h)

if initialization_accepted(result)
    workspace = EMTStudyWorkspace(result.prepared)
    trace = evaluate_emt_study!(workspace)
else
    error("$(result.failure.code): $(result.failure.message)")
end
```

For dependent data cases, parse the complete sequence, preview the source case, create an `EMTOperatingPoint` carrying its accepted state signature, and pass `DeckCaseInitialization` instructions to `run_deck_case_sequence_emt`. The sequence runner executes a mapped case only after its named predecessor has accepted and its signature matches; dependency failure remains explicit and never falls back to ordinary zero-state execution.

The runnable [`consistent_initialization`](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/consistent_initialization) case shows both harmonic formulations, a frequency scan, state inventory, exact typed voltage mapping, deterministic signatures, two-case sequencing, numerical tables, and a waveform using only public Julia APIs.

## Scope and limits

Consistent initialization proves only the apparatus families, formulations, quantities, topology domains, and tolerances represented by an accepted report and its independent evidence. It is not a power-flow replacement, an equipment recommendation, a proprietary-simulator equivalence claim, a manufacturer model, a standards-conformance result, or certification. Unsupported apparatus state is refused until its scientific owner supplies equations, complete state construction, coupled execution, independent evidence, and public validity limits.
