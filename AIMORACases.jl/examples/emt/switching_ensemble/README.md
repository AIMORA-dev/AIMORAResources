# Reproducible Switching Ensemble

This example varies a breaker closing instant systematically across seven EMT
energizations. The opening instant depends on the sampled closing instant:

\[
t_{\mathrm{open}}=t_{\mathrm{close}}+20\ \mu\mathrm{s}.
\]

A fixed random seed and explicit schedules make the study exactly replayable.
For each run AIMORA recomputes extrema and fits normal and Gumbel distributions
to the channel maxima.

## Model, units, and assumptions

Event times are seconds and response maxima are per-unit BUS3 voltage. Seven closing instants are distributed systematically about 50 µs with a 30 µs spread; each opening follows its closing by 20 µs. The seed `2026` fixes all stochastic choices and the exact schedules are passed back into execution. The small ensemble teaches orchestration and fitting and is not large enough to establish a design-level insulation probability.

## Run

```bash
make run
```

## Outputs

- `switch_schedules.csv`: event times for every energization.
- `ensemble_extrema.csv`: channel maxima and exceedance probabilities.
- `maximum_vs_switch_time.svg`: response maximum versus closing time.
- `summary.md`: replay signature and physical-check status.

Use this pattern for statistical switching-overvoltage studies.

## Interpretation

The schedule CSV is the reproducibility contract: rerunning with it must give the same replay signature and extrema. The maximum-versus-time plot shows sensitivity to point-on-wave/topology timing. Exceedance probability orders the observed maxima, while the preferred fitted distribution is only descriptive for these seven samples. Increase energizations and justify a timing distribution before making risk claims.
