# Modern EMT Machine Families

AIMORA provides six explicitly selected fixed-step instantaneous-EMT machine families: wound-field synchronous, cage induction, wound-rotor induction, permanent-magnet synchronous, doubly fed induction, and synchronous-condenser operation. Selection is a typed physical contract, not an instruction to infer missing windings or substitute a retained BPA machine. The public engine loads and prepares every family without the private solver; production network execution requires an explicitly activated backend.

## Equations, units, and signs

The ordered stator terminals are phases a, b, c, and neutral. One orthonormal, power-invariant zero/d/q transform at electrical angle ``\theta_e=p\theta_m`` maps phase voltage, current, and flux consistently:

```math
x_{0dq}=T(\theta_e)x_{abc},\qquad x_{abc}=T(\theta_e)^\mathsf{T}x_{0dq},\qquad v_{abc}^\mathsf{T}i_{abc}=v_{0dq}^\mathsf{T}i_{0dq}.
```

Winding circuits obey ``v=Ri+d\lambda/dt`` with rotor-speed coupling in the rotating axes. A symmetric inductance/coenergy relation owns stator, field, damper, cage, deep-bar, and wound-rotor currents. The declared convex saturation law includes reciprocal d/q cross derivatives; it cannot silently become an independent-axis curve. Electromagnetic torque comes from the same coenergy boundary used for current and power.

Runtime electrical quantities use peak instantaneous SI values: volts, amperes, ohms, henries, webers, watts, vars, joules, newton-metres, radians, radians per second, seconds, and hertz. Stator, field, and exposed rotor-port powers are positive into the machine. Mechanical torque is positive into the shaft. Generator export is therefore negative absorbed electrical power; family or operating-mode labels never reverse equation signs.

## Family and state selection

| Family | Required electrical state | Deliberately unavailable when absent |
| --- | --- | --- |
| Wound-field synchronous | Stator zero/d/q, field, d/q damper | Cage/deep-bar and permanent flux |
| Cage induction | Stator zero/d/q and one to eight passive d/q rotor branches | Field, permanent flux, exposed rotor voltage unless declared wound rotor |
| Wound-rotor induction | Stator and exposed d/q rotor circuits | Field and permanent flux |
| Permanent-magnet synchronous | Stator zero/d/q and declared permanent flux/saliency | Field, damper, and induction rotor currents |
| Doubly fed induction | Stator and exposed d/q rotor port with separate rotor power | Converter switching or control, which belongs to a later converter/plant owner |
| Synchronous condenser | Wound-field synchronous electrical state in explicit condenser mode | Static-var or ideal reactive-source substitution |

Every machine owns one through sixteen finite-inertia shaft masses. Declared shaft sections retain twist, stiffness, damping, action/reaction torque, kinetic energy, elastic energy, and angular momentum. The generic control boundary owns sampled excitation, governor, stabilizer washout/lead-lag, limit and tracking anti-windup state; task period and phase are exact state and cannot be replaced by continuous evaluation.

## Initialization, events, energy, and restart

The selected initialization mode and every initial phase, field, rotor-port, shaft, control, history, event, and energy quantity are explicit. A specified or sinusoidal operating point cannot hide a settling interval. Fixed-step trapezoidal execution assembles an analytic terminal current Jacobian from immutable trial state, accepts state once, and restores every electrical, shaft, control, task, event, energy, and output field after a rejected trial.

Electrical and mechanical command events are localized at exact accepted boundaries and ordered by time, priority, and identity. External terminal faults or source unbalance remain network topology/source events; machine field, rotor, torque, reference, and control-enable commands mutate only their declared ports. Protection logic and arbitrary internal winding faults are outside this release.

For each accepted interval, diagnostics account for terminal, field, rotor-port, and mechanical work; magnetic, kinetic, and elastic energy; and copper, deep-bar, iron, shaft, and damping loss. `maximum_energy_residual_j` is the unexplained companion-consistent discrete balance after the rotating-axis conversion work is reconciled with the shaft transaction. `maximum_energy_quadrature_defect_j` separately reports the method-local difference produced by integrating physical endpoint power with trapezoidal quadrature; it must refine with timestep and is not labelled physical energy creation. Snapshot identity binds family, topology, source, timestep, task, and parameter signature. A compatible restore reproduces the next companion and complete continuation exactly; a stale identity is refused.

## Public executable products

Seven redistributable generic products each execute 1,000 fixed 10 µs steps, apply one source-unbalance and machine command boundary at 5 ms, retain typed state/results, verify an exact midpoint restart, and write CSV, report, summary, and curated SVG artifacts:

- [Wound-field synchronous generator](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_wound_field_synchronous)
- [Single-cage induction motor](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_cage_induction)
- [Four-branch deep-bar induction motor](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_deep_bar_induction)
- [Permanent-magnet synchronous generator](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_permanent_magnet)
- [Doubly fed induction generator machine port](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_doubly_fed_induction)
- [Synchronous condenser](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_synchronous_condenser)
- [Eight-mass controlled wound-field machine](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/machine_multimass_controls)

The matching generic catalogue records exact family, terminal/axis/rotor/shaft/control order, source, rights, SI transformation, uncertainty, validity, and parameter nature. These values are original synthetic examples, not manufacturer records.

## Evidence, performance, and limits

Independent Julia formulations cover the phase transform, coenergy current and reciprocal derivatives, synchronous/induction/permanent-flux/DFIG circuits, multi-mass shaft, controls, initialization, and energy without reusing production stamp/history code. Focused qualification adds analytical limits, h/h2/h4 and rotor/shaft refinement, phase and parameter metamorphisms, deliberate mutations, coupled network events, restart, and equal-accuracy P0–P2 measurements. External overlap is limited to exact registered retained BPA behavior and pinned headless OpenModelica/Modelica Standard Library component mappings; it does not establish ATP/PSCAD equivalence.

The admitted generic domain is three-phase three- or four-wire, 0.1 kW–2 GW, 10 V–765 kV, 5–400 Hz, 1–50 pole pairs, 0–2 per-unit speed, induction slip -1–1, DFIG slip -0.5–0.5, up to two damper circuits per axis, one to eight passive rotor branches, one to sixteen shaft masses, and 100 ns–500 µs fixed timestep subject to waveform resolution and refinement. Each product narrows that domain.

This release does not claim finite-element air-gap fields, spatial harmonics beyond the declared winding representation, hysteresis, thermal aging, arbitrary internal winding faults, protection behavior, converter execution at the DFIG port, vendor/controller equivalence, protected-standard conformance, field or HIL qualification, certification, or universal ATP/PSCAD equivalence. Unknown manufacturer, measurement, field, and model-form uncertainty remains unknown.
