# AIMORA

**Analytical Integration for Multiphase Overvoltage and Response Analysis**

AIMORA is a Julia-native platform for power and energy systems. It combines open engineering interfaces with separately distributed production capabilities:

- public study contracts, project schemas, models, cases, catalogs, and reporting boundaries;
- an external compiled BPA EMTP reference for qualification, never for the production timestep loop.

The authorized engine preserves the generated `aimora_bpa_emtp_replacement_v4` Julia-only regression set and adds separately bounded modern EMT owners for events, transactions, exact schedules, semiconductor fidelity, bridge topology, converter controls, extended converter systems, initialization, snapshots, lines, transformers, machines, measurements, protection, surges, multirate execution and optional DASSL-class average/passive integration. Each chapter states its exact accepted boundary; this does not imply completion of the broader planned EMT platform, power flow, short circuit, arc flash, unified phasor dynamics, optimization, graphical workflows, universal ATP/PSCAD equivalence or certification.

## Repositories

| Repository | Visibility | Purpose |
|---|---:|---|
| [AIMORA.jl](https://github.com/AIMORA-dev/AIMORA.jl) | Public | Open engine contracts and package entrypoint |
| [AIMORAResources/references/bpa_emtp](https://github.com/AIMORA-dev/AIMORAResources/tree/main/references/bpa_emtp) | Public | Compiled historical reference |
| [AIMORAResources/AIMORACases](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases) | Public | Versioned examples and benchmark inputs |
| [AIMORAResources/AIMORACatalogs](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACatalogs) | Public | Open equipment data and study facets |
| [AIMORAResources/AIMORAReferenceModels](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORAReferenceModels) | Public | Independent analytical and manufactured scientific checks |

Installation and licensing information for production capabilities is published through the product distribution channel.
