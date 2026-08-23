# Study Catalog and Scenario Data

This Julia-only example is the orientation point for AIMORA's open engineering
core. It creates a project, case, scenario, inverter asset table, and EMT study
settings, then compares the complete top-level study API catalog with the currently implemented study APIs. This is an API-maturity inventory, not an overall product-completion or EMT-capability percentage; accepted mechanisms inside `emt` are not counted as separate studies.

## Run

```bash
make run
```

## Data model

The ownership hierarchy is

\[
\text{Project}\supset\text{Case}\supset\text{Scenario}
\supset\{\text{asset tables},\text{study settings}\}.
\]

An inverter row records its bus, rating, voltage base, active/reactive
references, enabled state, and model family. The EMT input profile separately
states the required timestep, duration, network elements, and initial
conditions. Keeping assets and study settings separate lets one asset model
support several scenarios.

## Outputs

- `study_catalog.csv`: every advertised study, domain, status, and owner.
- `inverter_assets.csv`: the scenario's typed inverter rows.
- `emt_input_profile.csv`: required and optional EMT inputs.
- `study_status.svg`: cumulative implemented versus planned study counts.
- `summary.md`: hierarchy identifiers and catalog totals.

Only rows reported as `implemented` are presented as executable studies in the
rest of this gallery. Planned rows are a roadmap, not a claim that a numerical
workflow already exists.
