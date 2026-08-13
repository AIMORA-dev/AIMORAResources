# Extended Semiconductor Fidelity

AIMORA extends the existing `PowerSemiconductorSwitch` owner with explicitly selected generic fidelity components. The unextended diode, thyristor, IGBT, and MOSFET constructors retain their existing ten-channel trace and piecewise-linear behavior.

## Admitted components

The public engine can compose recovered minority-carrier charge, continuous nonlinear junction charge, exponential turn-off tail current, deterministic switching-event energy tables, passive one-through-eight-stage Cauer thermal state, bidirectional TRIAC latching, and gate-turn-off thyristor refusal policy. Each component owns typed SI parameters, provenance, uncertainty, and a bounded validity domain.

Recovered charge uses the accepted backward-Euler balance

```math
q_n = \max\!\left(0, \frac{q_{n-1}+\Delta t\,i_d}{1+\Delta t/\tau}\right).
```

The nonlinear junction satisfies `dq/dv = C(v) > 0`; displacement current is the accepted charge difference divided by the candidate timestep. Turn-off tail current is nonnegative and decays exponentially to its declared cutoff. Switching energy is trilinearly interpolated without extrapolation and is deposited once after an accepted event. The Cauer network has strictly positive thermal resistance and capacitance and rejects heat to a declared ambient temperature.

## Runtime ownership and state

An extended switch is passed to the nonlinear-device list and must not simultaneously appear in the linear element list. The private solver prepares one exact candidate time, timestep, and integration method before residual/Jacobian evaluation. Trial evaluation is non-mutating. Charge, tail, event energy, loss, temperature, and history state change only after the coupled network solution is accepted; a failed acceptance restores the complete transaction.

`power_semiconductor_extended_state` reports selected components, conduction direction, GTO disposition, recovered charge/current, nonlinear capacitance/charge/displacement current/stored energy, tail state, event and cumulative energies, thermal temperatures, ambient heat flow, and stored thermal energy. Baseline trace channels and `PowerSemiconductorTerminalState` remain unchanged.

## Provenance and uncertainty

Generic parameters must name a source, SI units, transformation, uncertainty or explicit unknown, validity domain, and physical parameter nature. A manufacturer name is unavailable without lawful, versioned device evidence. Energy tables refuse coordinates outside their axes. Junction and thermal state refuse their declared voltage or temperature domains. A declared compact schema is hash-, version-, licence-, and redistribution-bound and is not an arbitrary SPICE, HDL, encrypted, or proprietary model loader.

## Public case

`AIMORACases` case `emt_extended_semiconductor_commutation` uses a synthetic generic recovered diode with nonlinear junction charge, event-energy axes, and a passive two-stage thermal network. It records voltage, current, charge, displacement current, temperature, and cumulative dissipated energy. Public users can inspect the contracts, parameters, independent reference equations, and results; production execution requires an explicitly activated private backend.

## Limits

This capability does not establish manufacturer prediction, arbitrary compact-model compatibility, drift-diffusion or spatial device physics, destructive failure, ageing or lifetime, protected-standard conformance, ATP/PSCAD equivalence, or certification. A generic parameter set cannot inherit any of those claims. Bridge and converter family qualification remains separate.
