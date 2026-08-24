# Surge and Insulation Platform

AIMORA's surge and insulation layer supplies separately selected instantaneous-EMT models for interruption and fault arcs, metal-oxide arresters, lightning currents and multistrokes, tower/channel traveling waves, linear and ionizing grounding, disruptive-effect and leader flashover, dynamic corona, GIS/GIL terminal sections, and deterministic statistical insulation studies. It extends the accepted nonlinear, event, line, transformer, breaker, snapshot, and result owners; it does not create a second timestep loop or imply a complete insulation-design tool.

## Public products

The `emt_surge_insulation_platform` case executes five original generic products:

1. Three independently represented poles combine bounded Cassie-Mayr conductance, chopping current, dielectric recovery, extinction, and restrike state.
2. A double-exponential lightning current drives a nonlinear metal-oxide arrester at an apparatus terminal while charge, absorbed energy, residual voltage, peak current, and lumped thermal duty advance only after coupled convergence.
3. A deterministic multistroke drives a two-section tower connected to a line surge termination, an ionizing footing, and a polarity-specific flashover insulator.
4. A very-fast Heidler current drives a passive GIS/GIL RLCG terminal with dynamic corona charge/loss and leader state.
5. A preregistered seeded stress-strength ensemble reports every draw, margin, failure flag, empirical probability, Wilson interval, and deterministic signature.

Each product has a public immutable specification, a solver-free readiness result, a private-backend readiness result, an exact preparation signature, CSV output, SVG plot, and explicit unsupported boundary. Selecting one product never silently substitutes another family.

## Equations and signs

All runtime quantities use peak SI units. Branch current is positive from the declared positive terminal to the negative terminal, positive branch power enters a device, injected lightning current follows its declared terminal direction, and ground-potential rise is positive at the electrode node relative to reference ground.

The normalized double-exponential source is

```math
i(t)=\frac{I_p}{\eta}\left(e^{-\alpha t}-e^{-\beta t}\right),\qquad \beta>\alpha>0,
```

where the normalization `η` is evaluated at the analytic peak time. The Heidler source uses `x^n/(1+x^n) exp(-t/τ)` and solves the monotone peak condition `t(1+(t/τ_f)^n)=nτ` rather than sampling a nominal peak.

Combined arc conductance advances a bounded exponential balance blending Cassie and Mayr power-rate laws by instantaneous dissipated power. Fault arcs use a separately identified Mayr-family cooling balance. Vacuum contacts retain contact-separation time, chopping threshold, dielectric strength, open/restruck state, and transition counts; they do not represent a manufacturer interrupter.

Metal-oxide current is continuous and monotone across log-log power-law segments. Charge integrates current, energy integrates nonnegative absorbed power, and temperature integrates absorbed power minus the declared lumped cooling law. A dynamic equivalent declares two nonlinear columns, lead/filter R-L branches, and shunt capacitance; it is never collapsed silently to the static characteristic.

The positive-real grounding model evaluates `G0 + Σ rₖs/(s+pₖ)` with nonnegative residues and positive poles. The compact ionizing model expands a bounded effective radius only above its declared critical field and otherwise recovers toward the electrode radius. It is a dissipative engineering boundary, not a touch/step-potential or grounding-safety design model.

Disruptive effect integrates positive and negative overvoltage stress separately. The leader model integrates polarity-specific field-excess velocity over the remaining gap. Flashover changes to an explicit finite conductance only at the accepted surface. Corona uses a hysteretic voltage-dependent charge with explicit loss conductance and preserves charge and loss through restart.

Traveling waves use oriented multiconductor characteristic impedance: `v⁺=(v+Zi)/2`, `v⁻=(v-Zi)/2`. Tower/channel paths preserve every section travel time and attenuation. GIS/GIL terminal sections expose full symmetric passive R, L, G, and C matrices and the declared enclosure reference.

## Workflow

Run the public example from the Resources checkout:

```text
julia AIMORACases/examples/emt/surge_insulation_platform/run.jl
```

The production solver must be installed beside the public engine or provided through `AIMORA_SOLVER_PATH`. Without it, product specifications, catalogues, readiness, equations, and stored results remain inspectable, while coupled execution reports the backend as unavailable.

Use the generated CSVs for exact numeric inspection and the SVGs for curated waveform review. The summary binds product/preparation signatures and reports peak terminal quantities, arrester duty, tower flashover state, travel time, ground-potential rise, GIS response, and statistical interval. Changing a model, parameter, topology, source, timestep, seed, or output contract invalidates the preparation and evidence identity.

## Validity and limitations

The published parameters are synthetic, generic, and nonvendor. The examples qualify the declared equations and execution paths on their stated fixed timesteps and domains; they do not establish induced-lightning electromagnetic fields, arbitrary soil/geometry extrapolation, grounding safety, partial discharge, insulation aging or lifetime, manufacturer/utility behavior, protected-standard withstand or switching-impulse conformance, field/laboratory accuracy, ATP/PSCAD equivalence, safety integrity, or certification.
