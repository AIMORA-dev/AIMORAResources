# Classic Case 0007 — Capacitor-Bank Recovery Voltage

## Purpose

Three source-fed phases energize an ungrounded shunt capacitor bank. The three
bank switches open at 1 ms. The resulting voltage across each open pole is the
transient recovery voltage relevant to interruption duty.

## Model and equations

For each capacitor branch,

\[
i_C=C\frac{dv_C}{dt},
\]

while the open-pole recovery voltage is the difference between the continuing
source-side voltage and the trapped bank-side voltage,

\[
v_{\mathrm{TRV}}(t)=v_{\mathrm{source}}(t)-v_{\mathrm{bank}}(t).
\]

The deck uses a 60 Hz balanced source, 0.01 Ω source resistance, delta/ungrounded
bank connections, capacitor field values of 1000, a 50 µs step, and a 50 ms
horizon.

## Run and outputs

```bash
make run
```

The CSV includes every requested node/output channel; the SVG selects the first
requested physical channels. Inspect the 1 ms neighborhood and the subsequent
60 Hz separation between source and trapped charge. `summary.md` reports the
actual peak rather than a prescribed expected value.

The exact waveform artifacts are `classic_case0007_capacitor_bank_recovery_voltage_timeseries.csv` and `classic_case0007_capacitor_bank_recovery_voltage_waveforms.svg`.

Provenance and rights: [../SOURCE.md](../SOURCE.md).
