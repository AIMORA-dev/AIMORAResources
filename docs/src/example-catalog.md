# Example Catalogue

`AIMORACases.jl/examples/catalog.toml` is the machine-readable index of public executable cases. Every registered row declares a stable case ID, study family, entry point, engineering description, solver requirement, result kind, source/provenance IDs, and whether comparison with the admitted historical reference is meaningful.

The canonical detailed documentation for an individual case is the `README.md` stored beside its `run.jl`, input deck, Makefile, and committed output products. This prevents the manual and executable example from drifting apart.

## Run the complete gallery

```bash
cd AIMORAResources/AIMORACases.jl
make check
make test
make example
```

## Run one case

```bash
make -C examples/emt/rlc_energization run
```

Use the local Makefile because it selects the correct package environment and output directory.

## Case-directory contract

Every registered executable case must contain:

```text
case-directory/
  README.md          engineering objective, model, inputs, run command, outputs, interpretation, limits
  run.jl             Julia entry point
  Makefile           run and clean commands
  input data         .deck, TOML, CSV, or typed Julia fixture as declared
  outputs/           canonical nonempty result products
  provenance         local or shared source/licence record when adapted
```

A catalogue row without a substantive README, executable consumer, or result product fails the documentation/content gate.

## EMT example families

### Introductory networks

- RLC energization and discharge;
- source, branch, switching, and requested-output basics;
- initial-condition handling;
- timestep and damping sensitivity;
- deterministic CSV/SVG/summary output.

Recommended first case: `emt_rlc_energization`.

### Switching and breaker phenomena

- capacitor-bank opening and back-to-back energization;
- restrike and reignition;
- fault clearing and reclosing;
- trapped charge and distributed history;
- current-zero behavior and localized discontinuities.

### Lightning, travelling waves, and insulation phenomena

- lightning-current impulses;
- tower and overhead-line propagation;
- fast-front insulator stress;
- cable/line modal and wideband propagation;
- surge-arrester nonlinear response.

### Nonlinear networks

- polynomial/exponential branches;
- ZnO arresters;
- ideal constraints;
- manufactured nonlinear KCL/MNA systems;
- topology changes, event refinement, chatter vetoes, and restart.

### Control and converter cases

- TACS signal chains and sampled tasks;
- average and switching converter examples;
- extended semiconductor behavior;
- VSC controls and filters;
- multirate task scheduling;
- user-defined component registration.

### Transformer and reactor cases

The gallery includes distinct cases for low-frequency terminal matrices, BCTRAN-style products, hybrid transformers, magnetic-equivalent circuits, wideband black-box models, grey-box ladders, white-box winding sections, and reactor/apparatus behavior. Each README states the fidelity tier and prevents one tier from being presented as universally equivalent to another.

### Rotating-machine cases

Registered public products cover:

- wound-field synchronous generator;
- cage induction motor;
- deep-bar induction motor;
- permanent-magnet synchronous machine;
- doubly fed induction machine;
- synchronous condenser;
- multi-mass shaft with excitation/governor/stabilizer/limiter tasks.

Each case documents electrical and mechanical state, event, energy, restart, report, and waveform products.

### Runtime and reproducibility cases

- exact checkpoint/restart;
- atomic rollback;
- event/task collisions;
- general rational multirate schedules;
- sparse/nonlinear execution boundaries;
- performance demonstrations with declared hardware/size limits.

## Line-constants examples

Line examples cover single- and double-circuit towers, bundled conductors, earth wires, transposition, sequence/modal results, and high-frequency evaluation. Every case documents conductor ordering, geometry units, earth assumptions, frequency, requested transformations, and matrix/result files.

## Cable-constants examples

Cable examples cover single- and multi-layer constructions, centered/off-centre cores, screens/sheaths, bonding, geometry galleries, frequency scans, characteristic impedance, modal propagation, and report generation. Layer radii and conductor ordering are included in the case README.

## Transformer-parameter examples

These cases convert ratings and test data into declared branch/coupling parameters. Their documentation records bases, winding order, connection, assumptions, generated data, residuals, and quantities that cannot be inferred.

## Classic/reference-compatible examples

The `classic_emtp` family contains independently maintained Julia cases derived from lawfully redistributable or described classic test problems. The catalogue marks whether a case is compatible with the admitted compiled reference. Reference compatibility is case-specific and does not claim arbitrary legacy-deck compatibility.

## Output interpretation

Dynamic cases normally generate:

- `*_timeseries.csv` with time and typed channels;
- `*_waveforms.svg` with accessible vector plots;
- `summary.md` with timestep, duration, sample count, key extrema, and interpretation;
- optional checkpoint, JSON, report, energy, event, or diagnostic files.

Static cases normally generate:

- numerical matrices or parameter tables in CSV;
- frequency curves in CSV/SVG;
- text or Markdown engineering reports;
- machine-readable TOML/JSON summaries where appropriate.

## Programme-level catalogue audit

The source-coverage check reads `catalog.toml` and verifies for every registered case:

1. the entry point exists;
2. the declared primary input exists;
3. a substantive case README exists;
4. the output directory is nonempty;
5. the study family is implemented or the row is explicitly non-executable reference data;
6. source/provenance IDs are present;
7. no absolute workstation path, credential, compiled binary, or prohibited source extension enters a public example;
8. duplicate case IDs and duplicate canonical ownership are rejected.

## Adding a case

A new case is accepted only when the engine capability already exists. Add the case directory, README, run program, input, canonical outputs, provenance, and one catalogue row. Then run:

```bash
make check
make test
make example
```

A future-study placeholder must not be added as a runnable case.
