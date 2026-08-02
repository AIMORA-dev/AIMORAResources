# Small Parsed-Deck EMT Trace

This is an end-to-end deck tutorial: write readable deck rows, parse and
validate them, run a fixed-step EMT simulation, and generate AIMORA report
artifacts. It also demonstrates the fixed-card grounded-scalar reference form,
where later branches inherit a prior accepted scalar conductance.

## Run

```bash
make run
```

## Input model

The deck contains a stiff source, a two-bus resistive feeder, a timed tie
switch, and two grounded loads. The tie closes at 40 microseconds.

The companion fixed-card input defines a grounded branch with
(R=1.0\times10^6\ \Omega), hence (G=1/R=1.0\ \mu\mathrm{S}). Two later
rows reference that accepted owner and inherit exactly the same conductance.
The branch index is dimensionless and the plotted conductance is in siemens.

Assumptions: all three reference rows are grounded scalar conductances; a
reference must point backward to a previously accepted owner, and a missing
owner is rejected before the model mutates.

## Outputs

- `parsed_deck_trace.csv` and `parsed_deck_trace.svg`: primary node-voltage waveform.
- `parsed_deck_trace_summary.json`: parsed/executed dimensions and checks.
- `parsed_deck_trace_emtp_report.txt` and `parsed_deck_trace_report_manifest.json`: EMTP-style report and manifest.
- `parsed_deck_trace_over20_finalization.csv`, `parsed_deck_trace_over20_finalization_report.txt`, and `parsed_deck_trace_over20_finalization_manifest.json`: finalization artifacts.
- `grounded_scalar_branch_references.csv`, `grounded_scalar_branch_references.svg`, and `grounded_scalar_branch_references.md`: explicit and inherited grounded-conductance evidence.

Bus 3 is initially isolated from bus 2. Its voltage changes when the tie switch
closes, which makes the topology event easy to see in the waveform.

The grounded-reference plot should show three coincident values at
(1.0\ \mu\mathrm{S}). That equality confirms reference inheritance; it is a
parser and ownership result rather than a transient waveform.
