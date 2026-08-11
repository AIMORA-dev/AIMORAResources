# Source, Rights, and Normalization

## Upstream record

- Repository: `https://github.com/ahmelkholy/EMTP-BPA-CPP`
- Inspected commit: `ca4339d3f6f5d9f3dde377b4c96caeb21e466d00`
- Upstream location: `_Tests/EMTP-BPA/caseNNNN/test.dat`
- Upstream declaration: the repository README states that the translation and
  case material are licensed under the MIT License.
- Local form: electrical input data renamed from `test.dat` to `.deck`; no C++
  or Fortran source is copied or executed.

The upstream README attributes cases 0001–0014 and 0050 to examples described
in the *EMTP Primer*, and identifies case0003 as an ATPDraw export contributed
through the ATP user community. The Primer and ATPDraw application are cited
as background; their binaries and documents are not redistributed here.

## Exact inputs

Cases 0001, 0002, 0004, 0005, 0006, 0007, 0008, 0010, 0012, and 0013 are
byte-for-byte copies of the corresponding upstream `test.dat` at the inspected
commit.

## Repaired inputs

The remaining six inputs use the smallest normalization already exercised by
AIMORA's retained validation:

- **0003:** ATPDraw slash section markers are replaced by explicit blank-card
  terminators understood by the typed parser; trailing redundant blank markers
  are removed. Electrical values and the 10 ms switch event are unchanged.
- **0009:** the accepted horizon is 1.2 s so the 0.9172 s second-bank switching
  event is reachable; the upstream 40 ms horizon could never execute it.
- **0011:** two `LlNE` misspellings become `LINE`, `BSENO` becomes `BSEND`, and
  a tab before the `9999` terminator becomes fixed-field spaces.
- **0014:** malformed blank/mass terminators and free-form comments are
  normalized; the accepted long horizon is 200 s. The public runner uses a
  documented 0.2 s teaching window without altering the deck.
- **0015:** free-form universal-machine directive lines are normalized into
  accepted fixed-field cards; electrical and machine values are unchanged.
- **0050:** card-type/name typos, section terminators, source names, output
  cards, and controlled-switch rows are corrected. The unsupported expression
  spelling for `LAMDAR` is represented by its explicit 0.4 reference value.

Every local deck is parsed and run in a fresh Julia process during the example
gate. These are public examples and contract checks; compiled-reference
equivalence evidence remains private in `AIMORAValidation`.
