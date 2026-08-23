# Complementary Bridge Commutation

This Julia-only example drives one reusable AIMORA half-bridge with exact trailing-edge PWM and solves its coupled resistive-inductive load at a one-microsecond EMT step. The upper and lower positions are IGBTs with natural antiparallel-diode paths, finite on-state voltage, series-RC snubbers, a complementary gate interlock, and two microseconds of commutation dead time. The public bridge owner—not the example—decides the gate sequence and applies every due turn-off before any same-time turn-on.

The positive DC terminal is held at 400 V and the negative terminal is the reference node. The midpoint supplies an 8 Ω, 1 mH series R-L load. Device terminal current is positive from each switch's DC-side terminal toward its AC-side terminal, load current is positive from the bridge midpoint to the negative rail, and reported energy is in joules. The 20 µs carrier uses 50% duty. During each commanded transition, both applied gates must remain off for the configured dead time; the inductive current then transfers naturally through an antiparallel diode rather than violating the complementary interlock.

## Run

```bash
make run
```

## Outputs

- `complementary_bridge_commutation.csv`: exact tick/time, midpoint voltage, load current, applied gates, forward and reverse conduction states, KCL residual, losses, and stored/dissipated energy.
- `complementary_bridge_commutation.svg`: normalized midpoint voltage together with upper/lower applied gates and lower freewheel-diode state.
- `summary.md`: switching counts, dead-time and freewheel observations, maximum KCL residual, energy accounting, finite-state checks, and Julia-only ownership.

Interpret the zero-valued interval between upper and lower gate traces as the commanded dead time. A raised freewheel trace during that interval means the inductive current found the natural diode path. Acceptance requires no simultaneous applied gates or opposing conduction paths, at least one all-off dead-time sample, at least one antiparallel freewheel sample, exact unique PWM edge ticks, finite physical output, terminal KCL within 1e-10 A, relative terminal-energy residual no greater than 5e-4, nonnegative stored/dissipated energy, and deterministic Julia execution. This generic piecewise-linear bridge demonstrates commutation structure and network coupling; it assumes ideal zero-recovery diode commutation and is not a manufacturer compact model, measured switching-loss model, nonlinear-capacitance model, thermal model, or complete three-phase converter.
