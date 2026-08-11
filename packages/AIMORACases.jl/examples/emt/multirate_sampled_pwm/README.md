# Exact Multirate Sampled Control and PWM

This Julia-only demonstrator uses AIMORA's production exact scheduler for three rates on one integer microsecond calendar: a 1 µs electrical plant task, a 10 µs trailing-edge PWM carrier, and a 20 µs sampled controller with 3 µs computational delay. Each controller execution follows read, compute, delay, write, and zero-order hold; controller writes precede a same-tick PWM carrier by deterministic priority, and every PWM transition occurs on an exact integer tick.

The bounded first-order plant obeys \(\dot{x}=(g-x)/\tau\), where \(g\in\{0,1\}\) is the held PWM gate and \(\tau=40\,\mu\mathrm{s}\). The proportional sampled controller commands \(d=\operatorname{clamp}(0.55+0.8(r-x),0.05,0.95)\) with \(r=0.65\). This analytic plant is intentionally a scheduler/control demonstrator, not a converter, semiconductor-loss model, or electrical-network validation case; those physics belong to later Modern EMT packets.

## Run

```bash
make run
```

## Outputs

- `multirate_sampled_pwm.csv`: exact tick, time, plant state, held duty, and gate state.
- `multirate_sampled_pwm.svg`: plant, duty, and gate trajectories.
- `summary.md`: task counts, exact delay, edge uniqueness, bounds, and final state.

Acceptance requires exact integer occurrence ticks, every completed control write exactly three ticks after its sample, no duplicate PWM edge, finite bounded state, duty within `[0,1]`, and a gate trace identical to the PWM edge history.
