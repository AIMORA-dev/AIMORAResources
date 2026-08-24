# Cases and Catalogs

The optional DASSL-class variable-step EMT case publishes passive dense output and exact split/restart, nonlinear left/right switching states, an admitted wound-field machine/control trajectory, and a typed unsupported-owner refusal. It requires an explicitly configured private backend to generate production waveforms, while the public engine and catalog remain solver-free. See [Optional DASSL-Class Variable-Step EMT](dassl-class-variable-step-emt.md) for selection, equations, output contracts, and limits.

The EMT measurement public set includes seven generic products covering linear and saturating/remanent CTs, inductive VT, explicit CVT, electronic current and voltage sensors, and a complete three-phase sampled chain. Each writes physical/sample and estimator/diagnostic CSV/SVG pairs, a synthetic COMTRADE CFG/DAT record, and exact restart evidence; the generic catalogue owner is `generic_emt_measurement_chains`. See [EMT Instruments and Measurement Chains](emt-measurement-chains.md) for equations, clocks, signs, state, validity, and explicit exclusions.

The modern EMT machine public set includes seven generic products covering wound-field synchronous, standard cage, four-branch deep-bar, permanent-magnet, doubly fed induction, synchronous-condenser, and eight-mass controlled-machine execution. Each writes deterministic CSV data, a typed report and summary, and electrical plus mechanical SVG plots; the generic catalogue owner is `generic_modern_machine_families`. See [Modern EMT Machine Families](modern-emt-machine-families.md) for equations, state, signs, validity, evidence, and explicit exclusions.

The extended switching-detailed VSC public set includes `emt_extended_vsc_pll_dq`, `emt_extended_vsc_pr`, `emt_extended_vsc_droop`, and `emt_extended_vsc_virtual_synchronous`. Each case produces deterministic CSV data, a scalar summary, and current plus DC/sequence SVG plots; the generic catalogue owner is `extended_vsc_control_filter_platform`.

## Canonical cases

`AIMORACases` is the single public source for examples and benchmark inputs.
Tests and documentation should reference a case revision instead of copying
decks.

```julia
using AIMORACases

AIMORACases.available_cases()
AIMORACases.case_path(:emt_rlc_energization)
```

Cases are grouped by study, and each catalog row records its required product
capabilities and whether the compiled reference can consume it.

## Equipment catalogs

`AIMORACatalogs` stores open, versioned equipment data with common
nameplate fields and separate study facets.

```julia
using AIMORACatalogs

transformer = AIMORACatalogs.asset(:generic_transformer_10mva)
AIMORACatalogs.study_tabs(transformer)
AIMORACatalogs.study_facet(transformer, :power_flow)
```

Manufacturer or commercial data may be published only with recorded
provenance and redistribution permission. Synthetic entries must be labelled,
and no catalog entry implies manufacturer certification.
