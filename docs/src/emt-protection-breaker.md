# EMT Protection and Breaker Logic

AIMORA's fixed-step protection platform connects accepted physical-to-digital measurement products to causal relay elements, deterministic scheme logic and communication, exact protection tasks, and real three-pole EMT breaker contacts. It is an execution capability for explicitly configured generic schemes, not a relay-setting optimizer or a standard-conformance claim.

## Public product contract

Every `ProtectionProductSpecification` names its product family, protected asset and zone, inward-oriented terminals, accepted measurement products, element families, communication links, breaker targets, fixed network step, exact protection sample period, frequency domain, provenance, uncertainty, validity, and unsupported phenomena. `prepare_protection_product` validates the complete identity and initialization boundary without a private backend. `protection_product_readiness` distinguishes solver-free inspection from coupled production execution and retains a deterministic preparation signature.

The five public products are:

- radial phase overcurrent and residual earth fault with explicit primary/backup breaker, breaker-failure, autoreclose, reclaim, and lockout ownership;
- forward directional and mho distance line protection with one admitted incremental-wave decision and deterministic permissive communication;
- explicitly compensated transformer and bus biased differential protection;
- machine/converter accepted-frequency and causal past-window ROCOF supervision;
- DC-link differential and overcurrent logic with explicit terminal orientation.

All public settings are AIMORA-authored synthetic values. They are nonvendor, noncoordinated, nonmeasured, and noncertifying.

## Exact execution order

![Fixed-step protection mutation path](https://github.com/AIMORA-dev/AIMORAResources/raw/main/AIMORACases/examples/emt/generic_protection_products/outputs/protection_logic.svg)

At one exact logical instant, AIMORA releases an accepted measurement, evaluates elements, applies local logic, sends and delivers due messages, evaluates remote logic, and issues a trip command. The command starts breaker mechanism travel; a later exact boundary changes the public pole/contact state and the canonical TACS-controlled conductance in the physical nodal network. Failed task execution restores task-owned and shared protection state before returning an error.

Relay quantities retain their units and orientation: instantaneous quantities use SI peak state, selected phasors use A200 RMS `exp(j*omega*t)` channels, currents are positive into the declared zone, forward directional torque is positive, and apparent impedance is oriented loop voltage divided by oriented loop current. Missing, stale, clipped, low-magnitude, or calendar-incompatible measurements block through typed reasons rather than becoming zeros or inferred values.

## Outputs and interpretation

The [`generic_protection_products`](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/generic_protection_products) example writes one CSV, curated SVG, and signed summary for each product. The traces expose the element assertion, trip command, contact state, and load voltage before and after the physical breaker opens. The product and preparation SHA-256 identities bind the exact public configuration.

The generic breaker represents mechanism travel, pole position, closed/open conductance, optional accepted current-zero/contact-tail behavior, contact energy, failure deadline, backup request, dead/reclaim time, shot count, and lockout. Detailed SF6 or vacuum arc conductance, chopping, dielectric recovery, restrike, reignition, destructive interruption, and insulation behavior belong to a separate surge/insulation capability.

## Limits

This release does not claim IEC 60255, IEEE C37, IEC 61850, GOOSE, sampled-value, COMTRADE, synchrophasor, cybersecurity, telecom, relay, breaker, or switchgear conformance; vendor code or settings; field/laboratory timing; protection coordination or setting optimization; arbitrary line, bus, transformer, machine, converter, HVDC, or DC-grid schemes; precise traveling-wave fault location; physical synchronization; hard real time; physical HIL; detailed arc physics; safety integrity; ATP/PSCAD equivalence; or certification. Imported settings, calibration, records, timestamps, and event truth remain caller-owned.
