# Cable Geometry Gallery

This gallery compares four cable-constants configurations:

- type 2, one dielectric layer;
- type 2, two dielectric layers;
- type 3 pipe cable with a centered core;
- type 3 pipe cable with an off-centre core and two layers.

For each conductor/layer system, AIMORA builds

\[
\boldsymbol Z(\omega)=
\boldsymbol Z_{\mathrm{internal}}(\omega)+
\boldsymbol Z_{\mathrm{earth}}(\omega),
\qquad
\boldsymbol Y(\omega)=j\omega\boldsymbol C,
\]

reduces grounded conductors by a Schur complement, and solves modal
propagation from

\[
\boldsymbol\Gamma^2=\boldsymbol Z\boldsymbol Y,\qquad
\boldsymbol Z_c=\boldsymbol\Gamma^{-1}\boldsymbol Z.
\]

Radii and positions in the decks are metres, resistivity is Ω·m,
permeability/permittivity values are relative, frequency is hertz, and cable
length is metres.

## Run

```bash
make run
```

## Results

- `cable_geometry_metrics.csv`: conductor count, frequency count, first-mode
  characteristic impedance, velocity, and physical checks.
- `cable_geometry_impedance.svg`: first-mode impedance by geometry.
- `*_report.txt`: complete matrices and modal reports for each deck.
- `summary.md`: gallery interpretation.

All four decks are small public examples derived from distinct validation
geometries. They execute AIMORA's Julia cable study and do not invoke ATP or
Fortran.
