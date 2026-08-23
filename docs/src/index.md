# AIMORA

**Analytical Integration for Multiphase Overvoltage and Response Analysis**

AIMORA is a Julia-native platform for power and energy systems. It combines open engineering interfaces with separately distributed production capabilities:

- public study contracts, project schemas, models, cases, catalogs, and reporting boundaries;
- an external compiled BPA EMTP reference for qualification, never for the production timestep loop.

The authorized engine preserves the generated `aimora_bpa_emtp_replacement_v4` Julia-only regression set and adds the separately bounded Modern EMT 1.0 event, transaction, exact-scheduler, semiconductor, bridge, and one three-phase switch-detailed two-level VSC slice. This does not imply completion of other converter/control families, the broader planned EMT platform, power flow, short circuit, protection, arc flash, unified phasor dynamics, optimization, or graphical workflows.

## Repositories

| Repository | Visibility | Purpose |
|---|---:|---|
| [AIMORA.jl](https://github.com/AIMORA-dev/AIMORA.jl) | Public | Open engine contracts and package entrypoint |
| [AIMORAResources/references/bpa_emtp](https://github.com/AIMORA-dev/AIMORAResources/tree/main/references/bpa_emtp) | Public | Compiled historical reference |
| [AIMORAResources/AIMORACases](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases) | Public | Versioned examples and benchmark inputs |
| [AIMORAResources/AIMORACatalogs](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACatalogs) | Public | Open equipment data and study facets |
| [AIMORAResources/AIMORAReferenceModels](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORAReferenceModels) | Public | Independent analytical and manufactured scientific checks |

Installation and licensing information for production capabilities is published through the product distribution channel.
