# Results and Validation

AIMORA results are engineering evidence only when their quantity semantics, units, bases, signs, analysis windows, assumptions, warnings, numerical residuals, and comparison method are preserved. A plot without metadata is not a result contract.

# Typed result structure

The public study layer defines a typed result with:

- study identifier;
- status;
- quantities;
- assumptions;
- warnings;
- metadata.

## Status

| Status | Meaning | Required user action |
|---|---|---|
| `ok` | Execution and declared checks completed without noninformational warnings | Continue with engineering review |
| `warning` | Values exist, but assumptions, extrapolation, degraded evidence, or numerical concerns require review | Read every warning before use |
| `failed` | Numerical or execution failure | Do not use returned partial values as accepted results |
| `invalid_input` | Input, domain, units, topology, or request is invalid | Correct input; do not tune around the error |
| `not_implemented` | The requested study is declared but has no production implementation | Select an implemented study or wait for implementation |

## Quantity

A quantity should include:

- value;
- unit;
- optional base;
- description;
- stable key.

For arrays or time series, also record axes, labels/order, and sampling. For matrices, record terminal/phase/conductor ordering. For complex or phasor values, record convention and angle reference.

## Warnings

Warnings require stable code, severity, and message. Reports should distinguish:

- informational assumption;
- extrapolation or validity concern;
- numerical conditioning or convergence concern;
- missing evidence/output;
- degraded backend/fallback;
- safety/compliance limitation.

Warnings must travel with exported values.

# Time-domain waveforms

A waveform export requires:

- time in seconds;
- quantity name and target identity;
- unit and sign convention;
- sample/timestep policy;
- event timestamps;
- analysis window;
- decimation/filtering method;
- revision/run metadata.

Do not infer RMS, phasor, frequency, harmonic content, or steady state from an instantaneous waveform without a defined calculation window and method.

## Event review

For each expected event, verify:

1. request time;
2. executed/localized time;
3. state before and after;
4. collision ordering with other events/tasks;
5. topology revision;
6. physical consequence in quantities;
7. warning or rejection if the event did not occur.

Examples include switch close/open, current zero, fault insertion/clearance, gate transition, block/restart, protection operation, and sampled-task release.

## Sampling and decimation

Output decimation should not alter the internal solution. Record the decimation ratio/filter. A displayed waveform can miss switching peaks or alias harmonic content even when the simulation timestep is adequate.

# Power and energy

## Instantaneous power

Use the declared terminal orientation. For a multiphase device, document whether power is per phase or total. Sign should identify absorbed versus delivered power.

## Integrated energy

State the integration interval and initial stored energy. Typical terms include:

- source/external energy;
- resistive/device losses;
- capacitor electric energy;
- inductor/magnetic energy;
- machine kinetic energy;
- shaft energy;
- converter DC-link energy;
- arrester absorbed energy;
- numerical balance residual.

## Energy balance

A generic residual is:

```math
r_E(t) = E_{\text{external}}(t) - E_{\text{stored}}(t) - E_{\text{dissipated}}(t) - E_{\text{exported}}(t).
```

The exact sign and partition depend on the case boundary. Report absolute and normalized residual with a declared scale. A small absolute residual can still be unacceptable for a small-energy case; a relative residual can be misleading near zero.

# KCL and nodal residuals

For each solved node or terminal set, KCL residuals should be scaled and summarized over time:

- maximum absolute residual;
- RMS residual;
- normalized residual relative to representative current;
- time and node of maximum residual;
- residual around events and nonlinear iterations.

A local device residual and global nodal residual answer different questions; retain both where available.

# Nonlinear convergence

Review:

- initial/final scaled residual;
- iteration count per step/event;
- maximum iteration count and location;
- damping/line-search/limiting activation;
- rejected/retried steps;
- nonconverged state policy;
- sensitivity to timestep and initial condition.

Never accept a visually smooth waveform from a run that reported unresolved nonlinear failure.

# Frequency-domain and fitted-model results

## Parameter scans

A frequency scan should record:

- frequency axis and units;
- logarithmic/linear spacing;
- matrix/phase/mode order;
- magnitude/phase or real/imaginary convention;
- earth/material model;
- preprocessing and reduction;
- extrapolation outside samples.

## Fit error

For rational or wideband fitting, show error versus frequency rather than one aggregate metric. Include weighting and normalization. Review both matrix/terminal quantities and derived propagation/characteristic behavior when relevant.

## Stability

Report pole locations and any stability transformation. A fitted curve with unstable poles is not an acceptable runtime model.

## Passivity

Report minimum passivity margin and violation frequency before and after correction. Preserve the corrected-versus-original fit comparison. Passivity correction should not be hidden as routine preprocessing.

## Modal continuity

When modal transformations vary over frequency, review ordering, sign/phase continuity, conditioning, and mode crossing. Discontinuous modes can produce apparently reasonable pointwise eigenvalues but an invalid fitted dynamic model.

# Line and cable result interpretation

Review:

- full phase/conductor Z and Y matrices;
- sequence/modal transformations and order;
- characteristic impedance/admittance;
- propagation constant/delay;
- attenuation and phase velocity;
- frequency continuity;
- symmetry/reciprocity and conditioning;
- geometry and earth/material assumptions.

A sequence quantity is derived from the full matrix under a transformation assumption. Do not discard the full matrix when untransposed or asymmetric behavior matters.

# Transformer result interpretation

Depending on fidelity, review:

- terminal voltage/current and power;
- winding/branch parameters and bases;
- reproduction of no-load and short-circuit tests;
- core flux and magnetizing current;
- winding/internal-node voltages;
- saturation/hysteresis trajectory;
- rational fit/passivity for wideband models;
- energy/KCL/flux residuals;
- initial/remanent flux and switching point.

Do not treat a parameter-conversion report as an inrush or internal-insulation result.

# Machine result interpretation

Review:

- terminal phase/dq voltage/current;
- rotor angle and electrical/mechanical speed;
- slip for induction machines;
- electromagnetic and mechanical torque;
- electrical/mechanical power and losses;
- field, damper, cage/rotor, and saturation state;
- shaft mass angles/speeds and torsional torque;
- controller/limiter states and exact releases;
- energy and unbalance metrics.

Check sign conventions before comparing torque and power. Confirm whether angle is mechanical or electrical and whether speed is SI or per unit.

# Converter result interpretation

Review:

- DC voltage/current and DC-link energy;
- AC phase/pole/line voltage and current;
- P/Q and sign convention;
- gate commands and actual conduction state;
- modulation index, carrier, and control releases;
- dead time/interlock and protection/block state;
- device loss/energy only when supported by the selected semiconductor fidelity;
- filter current/voltage and resonance;
- switching/harmonic spectra using a valid sample/window policy;
- KCL and energy balance.

An average-value model cannot validate switching ripple or semiconductor stress. A switching model without electrothermal data cannot establish junction temperature or lifetime.

# CSV output

A professional CSV export should include or accompany:

- stable column names;
- units in names or a sidecar schema;
- time column and units;
- target/device identifiers;
- phase/conductor order;
- missing-value policy;
- numeric precision;
- revision/run metadata;
- warnings and assumptions reference.

CSV is a transport format, not a complete report. Do not separate it from the schema and run record.

# Plots and SVG output

Every engineering plot should contain:

- descriptive title;
- labeled axes and units;
- legend/trace identity;
- analysis interval;
- event markers where important;
- revision/case identity in caption or report;
- no misleading truncation or smoothing.

Use separate plots when quantities have incompatible units or scales unless a clearly labeled secondary axis is necessary. Do not hide warnings or failed checks behind attractive figures.

# Text and Markdown reports

A case report should be answer-first:

1. objective and case status;
2. software/data revision;
3. study/model/fidelity;
4. input and event summary;
5. principal results with units;
6. validation/diagnostic table;
7. warnings and limitations;
8. reproduction command;
9. artifact inventory.

# Validation hierarchy

Use the strongest feasible independent evidence.

## 1. Dimensional and invariant checks

- units and bases;
- positivity and bounds;
- matrix dimensions and symmetry expectations;
- event ordering;
- conservation and passivity;
- deterministic restart.

## 2. Analytical solutions

Examples include simple RLC responses, steady sinusoidal circuits, travelling-wave arrival time, and elementary machine/converter limits. State analytical assumptions.

## 3. Manufactured solutions

Construct input and expected response deliberately to exercise numerical behavior. Useful for residual/Jacobian, integration, interpolation, fitting, and parser testing.

## 4. Cross-formulation comparison

Compare independent model formulations within overlapping validity domains, such as lumped versus distributed at low frequency, direct versus modal, or low-order versus wideband. Agreement is expected only where assumptions overlap.

## 5. Historical-reference comparison

Historical references can support qualification, but their origin, revision, format conversion, and tolerance must be documented. A legacy reference is not automatically ground truth.

## 6. Independent software comparison

Compare against a separately implemented tool with matched topology, parameters, units, timestep, events, initialization, and output definitions. Differences in defaults must be removed before interpreting discrepancies.

## 7. Measured data

Measured validation requires sensor/channel provenance, calibration, sampling/synchronization, filtering, operating state, uncertainty, and parameter identification policy. Avoid tuning and validating on the same data without an independent holdout.

# Comparison metrics

Select metrics matched to the phenomenon:

- absolute and relative error;
- RMSE/NRMSE;
- maximum peak error;
- event-time error;
- overshoot/settling/rise time;
- frequency magnitude/phase error;
- energy/KCL residual;
- passivity margin;
- torque/speed/slip error;
- harmonic magnitude/THD error;
- checkpoint/restart maximum difference.

A single metric rarely captures all important behavior. Report analysis windows and normalization denominator.

# Acceptance thresholds

Thresholds should come from analytical precision, measurement uncertainty, engineering need, numerical convergence studies, or established qualification criteria. Do not choose a tolerance after seeing the result simply to force a pass.

A case can have multiple gates:

```text
execution completed
AND no invalid-input or solver failure
AND all required artifacts exist
AND event occurrence is correct
AND residuals are below declared limits
AND comparison metrics pass
AND warnings are accepted and documented
```

# Timestep and convergence study

For dynamic work, compare at least two or more progressively refined timesteps when the case is sensitive. Review principal quantities, event times, energy/residuals, and runtime. Establish that conclusions are stable at the chosen timestep.

For fitted models, similarly examine order/sample-grid/weighting sensitivity and passivity correction.

# Checkpoint/restart validation

Run an uninterrupted case and a checkpoint/restart case from identical input. Compare:

- terminal quantities;
- dynamic and delayed-history state;
- topology/switch state;
- control/protection/scheduler state;
- event occurrence;
- residuals and warnings;
- final result artifacts.

State whether the criterion is bitwise identity or a numerical tolerance. A checkpoint that restores only terminal values is incomplete for stateful models.

# Provenance and artifact manifest

Each run directory should include or reference:

- case ID and description;
- repository SHAs;
- Julia environment;
- input checksum;
- solver/backend metadata;
- run policy;
- start/end time and exit status;
- output file list with checksums;
- status, warnings, assumptions;
- validation summary.

Generated outputs should be clearly separated from hand-authored reference evidence.

# Result review checklist

Before using a result in a decision or publication, confirm:

- [ ] Study and model maturity are implemented for this use.
- [ ] Input units, bases, signs, phase order, and provenance are documented.
- [ ] Validity-domain checks pass.
- [ ] Initial state and event calendar are correct.
- [ ] Status and every warning were reviewed.
- [ ] Requested quantities include units and target identity.
- [ ] KCL/convergence/conservation/passivity checks pass as applicable.
- [ ] Timestep or fit-order sensitivity is acceptable.
- [ ] Independent comparison evidence passes.
- [ ] Checkpoint/restart passes for stateful released cases.
- [ ] Unsupported phenomena and uncertainty are stated.
- [ ] The reproduction command and revisions are retained.

The generated [Complete Runnable Case Catalog](generated/case-catalog.md) identifies the result kind and execution route for every registered public example. Case outputs remain the authority for numerical values; this manual never substitutes invented numbers for missing evidence.
