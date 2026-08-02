# Universal and Detailed Machine Gallery

This Julia-only example runs every shippable universal-machine and detailed
synchronous-machine deck promoted from AIMORA's validation corpus. It contains
29 canonical input decks, executes each through its production timestep owner,
and writes a complete time-series CSV plus an SVG waveform for every case. A
separate controlled experiment compares universal-machine types 1–12 under the
same excitation.

## Machine families

| Type | Physical interpretation |
| ---: | --- |
| 1 | three-phase wound-field synchronous machine |
| 2 | two-phase-armature synchronous machine |
| 3 | shorted-rotor induction machine |
| 4 | cage induction machine |
| 5 | two-phase shorted-rotor induction machine |
| 6 | single-phase stator with one field winding |
| 7 | single-phase stator with two rotor axes |
| 8 | separately excited DC machine |
| 9 | series-compound DC machine |
| 10 | series-field DC machine |
| 11 | parallel-compound DC machine |
| 12 | self-excited shunt DC machine |

## Included decks

| Group | Decks | What they demonstrate |
| --- | --- | --- |
| C307 automatic direct machines | `c307_automatic_direct_machine_type9.deck`, `type10`, `type11`, `type12` | Automatic initialization of the four direct-machine families. |
| Detailed synchronous machines | `detailed_synchronous_machine_universal_section.deck`, `synchronous_machine_saturated_delta_fleet.deck` | Single-machine SSR-style coupling and a three-machine saturated fleet with a delta-connected terminal. |
| Direct-machine fleets | `universal_machine_direct_fleet.deck`, `universal_machine_direct_coupled_fleet.deck`, `universal_machine_direct_electromechanical_fleet.deck`, `universal_machine_direct_tacs_fleet.deck` | Multi-machine electrical, shaft, and TACS/control coupling. |
| Base universal-machine families | `universal_machine_type1.deck` through `universal_machine_type12.deck` | All twelve accepted equation families on complete parsed-deck horizons. |
| Type-3 input and prediction modes | `universal_machine_type3_manual.deck`, `universal_machine_type3_normalized.deck`, `universal_machine_type3_predicted_current.deck`, `universal_machine_type3_normalized_predicted_current.deck`, `universal_machine_type3_remanent.deck` | Manual versus automatic initialization, SI versus normalized parameters, compensated versus predicted-current terminal coupling, and remanent flux. |
| Direct-machine variants | `universal_machine_type8_automatic.deck`, `universal_machine_type9_series_leakage.deck` | Automatic separately excited DC initialization and explicit compound-field series leakage. |

The directory contains exactly these 29 files. The runner checks the inventory
before simulation so a missing or silently added deck cannot be overlooked.
The intentionally nonconvergent type-3 deck remains a private negative test and
is not presented as a user example.

## Equations and inputs

Each electrical winding satisfies

\[
\boldsymbol v =
\boldsymbol R\boldsymbol i+\frac{d\boldsymbol\lambda}{dt},
\qquad
\boldsymbol\lambda = \boldsymbol L(\theta_m)\boldsymbol i,
\]

while the shaft state satisfies

\[
\dot\theta_m=\omega_m,
\qquad
J\dot\omega_m=T_e-T_L-D\omega_m.
\]

The synchronous-machine decks additionally solve the terminal Norton coupling

\[
\boldsymbol i_t =
\boldsymbol Y_m\boldsymbol v_t+\boldsymbol i_h,
\]

inside the network timestep. The fleet case assembles one coupled network with
three independently saturated machine states; the delta terminal admittance
has zero row sum and is updated when the saturation region changes.

Deck values carry their declared input basis. Absolute-mode resistance,
inductance, voltage, current, torque, time, angle, and angular speed are in
ohms, henries, volts, amperes, newton-metres, seconds, radians, and radians per
second. Normalized decks declare power/frequency-normalized machine data and
are converted by AIMORA before state initialization. Each deck owns its
timestep and end time; `deck_metrics.csv` records both.

The controlled type-1–12 comparison uses \(R=1\ \Omega\), leakage
\(L=0.01\ \mathrm H\), unsaturated axis inductance
\(L_d=L_q=0.05\ \mathrm H\), a 10 µs timestep, and a 0.1 V peak, 60 Hz test
voltage. Its fixed mechanical Thevenin boundary isolates electrical topology.
These compact values are teaching data, not equipment-rating recommendations.

## Execution routes

- Twenty-seven universal/direct-machine decks run with `run_deck_emt` for the
  complete deck horizon.
- The single detailed synchronous-machine deck runs with
  `run_deck_synchronous_machine_horizon`.
- The saturated three-machine case runs with
  `run_deck_synchronous_machine_fleet_horizon`.

Every parse uses a package-relative source label. The runner rejects invalid,
non-finite, deferred, or incomplete results.

## Run

```bash
make run
```

An alternative output directory can be supplied directly:

```bash
julia --project=../../.. run.jl /tmp/aimora-machine-gallery
```

## Results

- `<deck>_timeseries.csv`: all network-node and requested machine/control
  channels for one canonical deck.
- `<deck>_waveforms.svg`: up to six physically related machine-current,
  torque, speed, requested-output, or node-voltage traces selected in that
  order.
- `deck_metrics.csv`: input, runtime route, samples, timestep, duration, node
  and channel counts, plotted channels, and response extrema for all 29 decks.
- `machine_type_current_rms.csv` and `machine_type_current_rms.svg`: the common
  controlled excitation comparison for types 1–12.
- `machine_type_metrics.csv`: coil count, peak RMS-like current, peak torque,
  and final imposed-boundary speed for the controlled comparison.
- `summary.md`: executable coverage counts and finite-result assertion.

The deck plots are not legacy reference curves. They are reproducible outputs
from the current Julia production engine and are intended to teach input
construction, model selection, initialization, coupling, and result reading.
No Fortran source, executable, validation checkout, or ATPDraw file is loaded.
