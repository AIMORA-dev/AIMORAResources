# EMT Instruments and Measurement Chains

AIMORA provides seven explicitly selected fixed-step measurement products: linear current transformer, saturating/remanent current transformer, inductive voltage transformer, coupling-capacitor voltage transformer, electronic current sensor, electronic voltage sensor, and a complete three-phase sampled chain. Each selection is a physical-to-digital contract. It cannot silently become an ideal ratio, a nonloading observation, an offline whole-trace reducer, a controller-local signal, or another instrument family.

## Physical instruments and signs

Instrument-transformer windings use dotted-terminal voltage and inward-positive current. For signed turns ``N_k``, winding resistance ``R_k``, leakage coupling ``L_{k\ell}``, and core flux ``\Phi``, the admitted equations are

```math
v_k=\sum_\ell R_{k\ell}i_\ell+\sum_\ell L_{k\ell}\frac{di_\ell}{dt}+N_k\frac{d\Phi}{dt},\qquad \mathcal F=\sum_k N_k i_k.
```

The secondary winding closes through explicit series resistance/inductance and shunt capacitance for the burden and cable. Ratio and phase error therefore follow winding, excitation, burden, cable, timestep, frequency, and initial state rather than an ideal scale. A current-transformer secondary-open request outside its declared event domain is refused.

The magnetic CT maps branch flux to ``B=\Phi/A`` and winding ampere-turns to field ``H\ell``. Its scalar Tellinen state remains between ordered rising and falling limiting curves and owns direction, reversal memory, remanence, differential permeability, loop work, and accepted-only mutation. Rejected trials cannot alter remanence. The public example uses generic curves; it is not a manufacturer accuracy or saturation prediction.

The CVT represents both divider capacitors, the intermediate node, tuned series compensation reactor, suppression resistance/capacitance, electromagnetic unit, and burden. Capacitor charge and passive stored energy are

```math
q_b=C_bv_b,\qquad i_b=\frac{dq_b}{dt},\qquad W=\frac12\sum_b C_bv_b^2+\frac12L_c i_c^2,
```

while every internal node satisfies the declared incidence-matrix KCL. The static divider ratio is ``C_1/(C_1+C_2)`` and the series tuning frequency uses ``C_\mathrm{eq}^{-1}=C_1^{-1}+C_2^{-1}``; these metrics do not replace transient network execution.

Electronic sensors declare whether they insert a series current-loading branch or a shunt voltage-loading branch. Their passive real transducer and analog-conditioning sections obey

```math
\dot x=Ax+Bu,\qquad y=Cx+Du,
```

with stable poles, explicit input/output units and orientation, fixed-step trapezoidal state, accepted-only mutation, amplitude/spectral limits, and complete restart state. A labelled nonloading observer is a different declaration and cannot be inferred from a sensor name.

## Exact acquisition and digital state

Acquisition instants are exact integer ticks ``t_k=(n_0+k n_p)\Delta t``. The accepted analog endpoint is sampled at the declared same-time order, clipped before quantization, queued for an exact nonnegative integer-tick delay, released once, and held until the next release. A skipped acquisition or release, nonrepresentable clock, duplicate dispatch, or wrong ordering produces a typed refusal.

For a uniform quantizer,

```math
y_c=\min(\max(y,L),U),\qquad c=\operatorname{clamp}\!\left(\operatorname{round}_{r}\!\left(\frac{y_c-b}{\Delta}\right),c_{\min},c_{\max}\right),\qquad y_q=b+\Delta c.
```

The rounding rule, code bounds, scale, offset, clip flag, channel identity, engineering unit, and polarity are immutable. The three-phase public product uses ties-to-even rounding and never wraps a code.

For a complete causal ``N``-sample window ending at ``k``, AIMORA reports

```math
X_\mathrm{RMS}[k]=\sqrt{\frac1N\sum_{m=0}^{N-1}x[k-m]^2},
```

and, under the ``\exp(j\omega t)`` convention,

```math
\underline X[k]=\frac{\sqrt2}{\sum_m w_m}\sum_{m=0}^{N-1}w_m x[k-m]\exp(-j2\pi f_0t_{k-m}).
```

No RMS or phasor result is available before the window is full. The output retains window, source timestamp, release timestamp, latency, coherent gain, frequency convention, and quality.

For aligned abc phasors and ``a=\exp(j2\pi/3)``, sequence order is zero, positive, negative:

```math
\begin{bmatrix}X_0\\X_+\\X_-\end{bmatrix}=\frac13\begin{bmatrix}1&1&1\\1&a&a^2\\1&a^2&a\end{bmatrix}\begin{bmatrix}X_a\\X_b\\X_c\end{bmatrix}.
```

When positive-sequence magnitude and quality are valid, frequency follows the principal phase increment between exact sample times in the nominally rotating reference. A phase-order permutation requires an explicit map; a missing or low-magnitude phase does not receive a fabricated frequency.

## COMTRADE boundary

The public reader accepts a bounded declared subset of 1991, 1999, and 2013 CFG plus ASCII, BINARY, BINARY32, or FLOAT32 DAT input. It validates channel/sample counts, ordered indices, units, scale/offset, primary/secondary flag, sample-rate sections, timestamps, start/trigger order, time multiplier, byte size, raw range, and digital-word layout before constructing a record.

The deterministic writer emits the registered 2013 ASCII or little-endian BINARY32 subset. Safe file APIs require matching `.cfg`/`.dat` basenames, refuse missing directories and replacement of existing files, and impose resource limits. Synthetic public records prove only the implemented interchange subset; no protected-standard text, protected sample record, conformance, PMU, merging-unit, or certification claim is included.

## State, events, energy, and restart

Accepted state includes every represented physical winding, flux, remanence, capacitor, reactor, burden, transducer, filter, clock, queued sample, held value/code, ring buffer, square sum, phasor/frequency history, COMTRADE cursor, event, energy, count, quality, and deterministic identity field. Trial evaluation is pure with respect to accepted state. Acceptance mutates once; rejection restores the complete state.

The seven public products apply a source-magnitude change at 5 ms. Physical network/apparatus state is accepted before due acquisition, delay, estimator, and writer work. Exact midpoint restoration must reproduce the next physical companion, every later sample/code/quality value, file bytes, counters, and final signature.

Inward terminal power is positive supplied power. Winding, burden, suppression, transducer, and filter loss is nonnegative; magnetic, capacitive, inductive, and transducer storage is explicit. Digital processing exchanges no network energy. An unexplained active energy residual fails the physical step.

## Public executable products

Each generic product runs 1,000 fixed 10 µs physical steps, samples at 20 kHz, applies 100 µs exact delay, retains an 80-sample rectangular estimator window, releases 199 samples, writes waveform and diagnostic CSV/SVG pairs plus a synthetic COMTRADE CFG/DAT pair, and requires exact restart:

- [Linear CT](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_linear_ct)
- [Saturating/remanent CT](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_saturating_ct)
- [Inductive VT](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_inductive_vt)
- [CVT transient](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_cvt_transient)
- [Electronic current sensor](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_electronic_current)
- [Electronic voltage sensor](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_electronic_voltage)
- [Three-phase sampled chain](https://github.com/AIMORA-dev/AIMORAResources/tree/main/AIMORACases/examples/emt/emt_measurement_three_phase_chain)

The matching `generic_emt_measurement_chains` catalogue record preserves exact family, cases, SI bases, orientation, clocks, window, source, rights, uncertainty, validity, and unsupported phenomena. All example parameters are AIMORA-authored synthetic values.

## Evidence and performance boundary

Independent public Julia formulations cover reciprocal winding recurrence and energy, scalar Tellinen trajectory, CVT charge/RLC/KCL residuals, analog-filter recurrence, exact acquisition/delay, clipping and three tie rules, causal RMS/DFT/sequence/frequency, COMTRADE scaling/timestamps, and ASCII/BINARY32 bytes without importing production stamps, histories, scheduler, parser, snapshot, or backend code. Focused qualification additionally checks analytic limits, coupled events, h/h2/h4 and window/sample refinement, uncertainty alternatives, deterministic rollback/restart, adversarial mutations, and equal-accuracy P0–P2 execution.

Executable external overlap is bounded to exact registered versions and mappings of retained historical behavior, headless Modelica components, ngspice passive circuits, an independent COMTRADE parser, and independent DSP algorithms. Each overlap proves only the named equations, variables, units, mapping, artifacts, and version; none establishes universal ATP/PSCAD behavior or a protected instrument/recording standard.

## Validity and explicit limits

The general admitted contract spans one- and three-phase 45–65 Hz systems, 1 V–1 MV peak, 1 mA–200 kA peak, declared passive burden through 1 kΩ subject to family constraints, monotone magnetic curves and remanence inside their supplied grid, DC–5 kHz declared CVT/electronic/filter spectrum, 100 ns–100 µs fixed network timestep, exact 1–100 ksample/s acquisition with represented bandwidth below 0.4 of sample rate, 1–32-bit or declared-table quantization, exact delay through 1 s, and 4–4096-sample windows. Every public case narrows this domain, and timestep/window/sample refinement remains controlling.

This release does not claim arbitrary manufacturer or proprietary devices, protected accuracy/merging-unit/PMU/COMTRADE conformance, calibration, metering, utility or laboratory data, field-recording truth, protection behavior, arbitrary ferroresonance, noise/isolation/thermal physics not declared by a sensor, vendor transfer functions, universal ATP/PSCAD equivalence, HIL qualification, or certification. Unknown manufacturer, calibration, field, installation, environmental, timestamp, and model-form uncertainty remains unknown.
