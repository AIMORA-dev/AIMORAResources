# Type-18 Ideal Transformer

This example demonstrates the fixed-card type-18 ideal-transformer source.
The source constrains primary and secondary voltages without adding leakage
impedance:

\[
v_p(t)=n\,v_s(t),\qquad
i_s(t)=-n\,i_p(t),\qquad
v_pi_p+v_si_s=0.
\]

Here the turns ratio is \(n=2\). A 100 V constant source feeds the constrained
nodes through a resistive network, so the resulting node waveforms visibly
show the imposed voltage relationship and the network loading. Resistances are
ohms, time is seconds, and the timestep is 50 µs.

## Assumptions

The transformer is lossless and has no leakage impedance, magnetizing current, saturation, phase shift, or winding capacitance. Its current sign follows power entering each winding, which explains the minus sign in the current constraint. The imposed algebraic relation is solved together with the surrounding network rather than applied as an output rescaling.

## Run

```bash
make run
```

## Results

- `ideal_transformer_type18_timeseries.csv`: node and requested output
  channels.
- `ideal_transformer_type18_waveforms.svg`: selected transformer/network
  waveforms.
- `summary.md`: timing, node count, channels, and peak voltage.

The transformer is parsed, stamped, constrained, solved, and reported by
AIMORA's Julia runtime.

## Interpretation

Divide primary voltage by secondary voltage away from zero crossings and confirm a ratio of two. The instantaneous powers should cancel within solve tolerance. Any persistent ratio or power-balance error indicates a constraint/stamp problem; oscillation caused by omitted leakage or saturation is not expected from this deliberately ideal model.
