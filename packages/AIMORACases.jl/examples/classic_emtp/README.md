# Classic EMTP Example Corpus

This directory turns the complete numbered example set found in
`EMTP-BPA-CPP` into organized AIMORA examples. All 16 source cases are
present: `case0001` through `case0015`, plus `case0050`. No Fortran or C++
program is used at runtime. The `.deck` files are electrical input data read by
AIMORA's Julia parser and executed by Julia study owners.

## What every folder contains

- the local normalized or exact upstream `.deck`;
- `run.jl`, which calls only AIMORA Julia APIs;
- a Makefile with `run` and `clean`;
- a README explaining the physical model, equations, units, switching events,
  calculation path, outputs, and expected interpretation.

Dynamic cases generate a sampled CSV, an SVG waveform, and `summary.md`.
Line-constants cases generate a report, sequence-constant CSV, SVG result, and
summary. The steady-state case generates complex voltage phasors and a voltage
magnitude plot.

## Corpus

| Case | Study | Main phenomenon |
| --- | --- | --- |
| 0001 | EMT | series RLC step response |
| 0002 | EMT | parallel RLC capacitor discharge |
| 0003 | EMT | ATPDraw-authored RLC network |
| 0004 | line constants | 500 kV flat bundled line |
| 0005 | line constants | 345 kV double circuit |
| 0006 | line constants | 230 kV high-frequency geometry |
| 0007 | EMT | capacitor-bank recovery voltage |
| 0008 | EMT | back-to-back capacitor switching |
| 0009 | EMT | capacitor-switch restrike |
| 0010 | steady state | parallel EHV resonance and fault |
| 0011 | EMT | transmission-line reclosing and trapped charge |
| 0012 | EMT | lightning surge at a tower |
| 0013 | EMT | potential-transformer ferroresonance |
| 0014 | EMT/machine | subsynchronous resonance |
| 0015 | EMT/machine | universal induction machine |
| 0050 | EMT/TACS | thyristor firing control |

## Common numerical form

At each fixed time step AIMORA assembles the nodal companion equation

\[
Y_n(t_n)\,v_n=i_{\mathrm{source},n}+i_{\mathrm{history},n},
\]

solves for the node voltages, updates dynamic history states in the declared
mutation order, applies due switching/control events, and records requested
physical channels. Individual READMEs specialize this equation for the case.

Run the whole public gallery from the repository root:

```bash
make example
```

See [SOURCE.md](SOURCE.md) for exact commit, rights, hashes, and every
normalization made to the six repaired inputs.
