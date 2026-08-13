# Cases and Catalogs

The extended switching-detailed VSC public set includes `emt_extended_vsc_pll_dq`, `emt_extended_vsc_pr`, `emt_extended_vsc_droop`, and `emt_extended_vsc_virtual_synchronous`. Each case produces deterministic CSV data, a scalar summary, and current plus DC/sequence SVG plots; the generic catalogue owner is `extended_vsc_control_filter_platform`.

## Canonical cases

`AIMORACases.jl` is the single public source for examples and benchmark inputs.
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

`AIMORACatalogs.jl` stores open, versioned equipment data with common
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
