# FIX SOURCE Load-Flow Gallery

Seventeen Julia-executed decks demonstrate AIMORA's steady-state `FIX SOURCE`
preparation before a transient. The gallery covers:

1. scalar angle/Q, P/Q, and balanced three-phase P/V constraints;
2. coupled sequence, coupled phase-pi, and distributed-line networks;
3. controlled and initially closed switch topology;
4. induction machines with three-phase, two-phase, single-phase, cage, and
   two-axis rotor arrangements;
5. two-phase and wound-field synchronous machines, including saturation; and
6. a separately excited DC-machine voltage boundary.

For a source phasor \(\underline V_k\) and network admittance matrix
\(\boldsymbol Y\),

\[
\underline{\boldsymbol I}=\boldsymbol Y\underline{\boldsymbol V},\qquad
\underline S_k=P_k+jQ_k=
\underline V_k\underline I_k^*.
\]

AIMORA iterates source magnitudes and angles until the requested \(P\), \(Q\),
or voltage constraints satisfy the deck tolerance. Machine cases add their
typed steady-state equivalent or voltage boundary to the same network. The
coupled-sequence case also applies

\[
\boldsymbol Z_{abc} =
\boldsymbol A\,\operatorname{diag}(Z_0,Z_1,Z_1)\,\boldsymbol A^{-1}.
\]

All voltages in these educational decks are peak volts, branch resistance is
in ohms, and the branch `L` field is interpreted as reactance at the declared
60 Hz steady-state frequency. Machine data follows each deck's declared
absolute-SI mode; the files are intentionally compact qualification-scale
systems rather than equipment-rating recommendations.

## Run

```bash
make run
```

## Results

- `fixed_source_metrics.csv`: convergence, iterations, voltage, and mismatch
  metrics for each topology.
- `fixed_source_voltage.svg`: maximum solved source voltage across all 17 cases.
- `*_report.txt`: complete source, constraint, and phasor tables.
- `summary.md`: interpretation and convergence assertion.

These inputs are public, compact AIMORA examples derived from validation
coverage. They contain electrical data only and do not invoke Fortran.
