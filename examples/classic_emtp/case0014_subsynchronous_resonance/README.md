# Classic Case 0014 — Subsynchronous Resonance

## Purpose

This is the IEEE second benchmark-style self-excitation problem with 55%
series compensation, a 600 MVA synchronous generator, a step-up transformer,
an infinite bus, and a four-mass turbine-generator shaft.

## Coupled equations

The synchronous-machine electrical state is advanced in rotor coordinates:

\[
v_{dq0}=Ri_{dq0}+\frac{d\lambda_{dq0}}{dt}
+\omega_rJ\lambda_{dq0}.
\]

Electromagnetic torque couples into the shaft system,

\[
M\ddot{\theta}+D\dot{\theta}+K\theta
=T_m-T_e,
\]

while the series-compensated network is solved through

\[
Y_{\mathrm{network}}v=i_{\mathrm{source}}+i_{\mathrm{machine}}.
\]

The ordering matters: terminal prediction, network solve, current
compensation, machine state update, shaft update, and requested outputs are
all owned by the Julia horizon.

## Inputs and run

The deck timestep is 200 µs and its accepted long horizon is 200 s. The
teaching runner intentionally calculates 0.2 s (1,000 dynamic steps), enough
to show the disturbance and initial electromechanical response without making
an example run occupy the workstation for a long time.

```bash
make run
```

The waveform channels include generator electrical quantities, rotor angle/
speed, and shaft torque requests. Growth or beating at subsynchronous
frequencies is the key relationship to inspect; a long-term stability claim
requires rerunning a longer horizon.

## Outputs and interpretation

- `classic_case0014_subsynchronous_resonance_timeseries.csv` contains the coupled electrical, rotor, and shaft channels for the shortened teaching horizon.
- `classic_case0014_subsynchronous_resonance_waveforms.svg` plots a readable selection of the requested machine/network quantities.
- `summary.md` records the 0.2 s executed horizon, timestep, dimensions, and peak magnitude.

Look for coherent energy exchange between compensated-network current, electromagnetic torque, and shaft motion. The short run demonstrates coupled execution and the onset of modal behavior; it cannot determine the 200 s growth/decay envelope declared by the source deck.

Normalization details: [../SOURCE.md](../SOURCE.md).
