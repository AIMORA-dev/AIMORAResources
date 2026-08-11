# AIMORA Rights-Aware Review Library

This index describes the local review library materialized under `.aimora/cache/references/review_library/`. It deliberately separates redistributable sources from files that the current user may access but AIMORA may not publish.

## Local private collections

After the workspace setup step, `.aimora/cache/references/review_library/private/` contains local links to:

- `atpdraw-official-cases/`: all 93 authenticated cases listed by
  <https://www.atpdraw.net/cases.php>, including 93 circuit packages,
  93 preview images, 93 saved descriptions/posts, 111 unpacked project/support
  files, and all 7 included PDF files.
- `atpdraw-7.8p1/`: the official ATPDraw 7.8p1 distribution and its bundled
  Exa project collection.
- `eeug-account-archive/`: the 56 files downloaded through the user's licensed
  EEUG account, together with the member-file inventory.
- `ATP-materail/`: user-supplied installers, archives, manuals, and recordings.
  Its private manifest records 96 source files, six exact duplicate groups,
  and passing integrity checks for all 18 ZIP/RAR archives. The
  `official-atpdraw-case-zips/` subdirectory contains 93 individual official
  case bundles plus one complete-corpus ZIP and SHA-256 checksums.

These links and their targets are ignored by Git. Access does not imply a right to redistribute. Do not copy a private ATP, ACP, executable, manual, or paper into a public repository unless its licence or the author explicitly allows redistribution.

The ATPDraw case manifest is
`.aimora/cache/references/review_library/private/atpdraw-official-cases/manifest.json`; its CSV companion is convenient
for sorting by title, author, date, or case ID. Each row includes checksums,
source URLs, descriptions, local paths, and a rights label.

## Public/open collection

Open-access papers and public specifications may be promoted into `AIMORAResources/references/` only after their source and redistribution terms are recorded. Bibliographic metadata alone may be indexed even when a full text cannot be redistributed.

## AIMORA conversion boundary

Raw ATPDraw projects are research inputs, not Julia examples. A shippable
conversion must:

1. state the original case ID, URL, author, and rights basis;
2. express the accepted input through AIMORA's Julia APIs or deck parser;
3. explain equations, units, assumptions, and unsupported effects;
4. generate finite reproducible Julia results and waveform/static artifacts;
5. avoid any Fortran or ATP runtime dependency.
