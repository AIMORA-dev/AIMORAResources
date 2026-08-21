# AIMORA Report Template Library

This directory owns declarative, versioned semantic report profiles. A template defines document structure, mandatory section roles, supported study families, output profiles, localization/branding slots, trust class, and licence. It does not contain study equations, numerical transformations, physical results, or compliance decisions.

## Version 1 profiles

| Template ID | Purpose |
| --- | --- |
| `engineering-standard` | General engineering calculation/study report |
| `research-reproducible` | Research note, paper supplement, or reproducibility report |
| `qualification` | Validation and qualification evidence report |
| `education-laboratory` | Teaching/laboratory report |
| `emt-study` | Electromagnetic-transient study |
| `line-cable-constants` | Overhead-line or cable-constants study |
| `transformer-parameters` | Transformer parameter-conversion report |
| `combined-study` | Traceable cross-study report with dependency DAG |

The machine-readable inventory is `v1/manifest.toml`.

## Trust boundary

- `builtin-reviewed`: AIMORA-authored, repository-reviewed, licensed, and validated.
- `signed-external`: external profile admitted only with signature, provenance, rights, and compatibility evidence.
- `project-local-trusted`: user/project profile explicitly trusted for that project.
- `untrusted`: parsed as data but prohibited from TeX compilation, shell escape, network access, arbitrary includes, or executable hooks.

## Separation of concerns

- **Template:** document structure and required semantic roles.
- **Theme:** typography, spacing, color, and renderer style.
- **Branding:** organization/client identity and legal markings.
- **Localization:** language, date, number, and unit presentation.
- **Provider:** study-specific semantic content from typed results.
- **Renderer:** Markdown/HTML/JSON/TeX/PDF/SVG/CSV/TikZ conversion.

No template may recompute study physics or read private solver data.

## Validation

A released template must pass:

- required manifest fields;
- semantic version and stable ID;
- licence/provenance completeness;
- trust-class policy;
- required section-role compatibility;
- supported-study declaration;
- deterministic parse/hash;
- example report build;
- renderer compatibility;
- restricted asset refusal.

## Usage

```julia
using AIMORAReporting

template = load_template("AIMORAResources/report-templates/v1/engineering-standard.toml"; trusted = true)
manifest = render_bundle(report, "outputs"; template = template)
```

Publisher-, standard-, manufacturer-, organization-, client-, logo-, font-, and artwork-specific assets are not implied by these generic templates. They require exact redistribution rights and external compatibility evidence.
