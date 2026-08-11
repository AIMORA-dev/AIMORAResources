# Machine–TACS Signal Interface

This focused Julia example shows how synchronous-machine state is transferred
to TACS/control storage. It is useful when building excitation, governor, or
machine-protection controls.

## Model, units, and assumptions

The interface reads an immutable snapshot of the machine's previous accepted history and routes request codes into explicit TACS storage indices. Positive and negative request codes select documented electrical, mechanical, or control quantities; their units follow the requested physical signal, while the CSV retains raw example values. The numbers are deliberately distinguishable routing inputs rather than a physically initialized generator. No network solve, timestep integration, or control feedback occurs in this focused transfer slice.

## Run

```bash
make run
```

## Outputs

- `machine_tacs_transfer.csv`: request code, physical meaning, destination
  storage index, and transferred value.
- `machine_tacs_transfer.svg`: transferred values by request order.

This is an interface-state example rather than a complete machine waveform.
For a network-coupled machine trajectory, use `universal_machine_type3`.

## Interpretation

Use the request, kind, and storage-index columns together: each output value must come from the expected prior-state owner and land at the expected ETAC location without overwriting unrelated slots. The bar-like SVG is indexed by request order, not time. Correct values demonstrate deterministic signal routing; they do not establish machine electromagnetic accuracy.
