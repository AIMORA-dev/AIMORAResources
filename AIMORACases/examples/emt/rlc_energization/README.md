# RLC Energization

This canonical Julia-only EMT case energizes a shunt capacitor through a series
resistance and inductance. It is the best starting point for understanding
timestep selection and RLC companion models.

## Model, units, and assumptions

For the series R–L path feeding the capacitor, the continuous relation is \(LC\,d^2v_C/dt^2+RC\,dv_C/dt+v_C=v_s\). The fixed-card deck supplies resistance, inductance, capacitance, source amplitude, and the requested output using AIMORA's documented electrical card units; the report normalizes solved channels in per unit and records time in seconds. Initial stored energy is zero, the source is admitted at the case boundary, and components are ideal lumped elements without parasitics.

## Run

```bash
make run
```

## Inputs

The catalogued fixed-card deck defines a 10-microsecond timestep, a 10-ms
duration, source excitation, series R-L branch, and shunt capacitor.

## Outputs

- `rlc_energization_timeseries.csv`: every node and requested output channel.
- `rlc_energization_waveforms.svg`: voltage/current response.
- `summary.md`: timestep, duration, sample count, and peak voltage.

The inductor limits the initial current. Energy then transfers into the
capacitor, producing the characteristic second-order transient.

## Interpretation

The first samples should show finite current rather than an impulsive capacitor charge. Depending on damping, capacitor voltage rises with a decaying oscillatory or monotone envelope toward its forced value. Reduce the timestep and compare peaks to assess numerical resolution; changing R changes damping, while L and C change the natural frequency \(1/(2\pi\sqrt{LC})\).
