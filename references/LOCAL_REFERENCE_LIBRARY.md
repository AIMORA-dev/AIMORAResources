# AIMORA Local Scientific Reference Library

The workspace materializes local third-party scientific source checkouts under `.aimora/cache/references/`; this file records their ownership and redistribution boundary without committing the downloaded library.

- `bpa_emtp/` is the tracked independent compiled historical-reference owner.
- `.aimora/cache/references/review_library/` is the local rights-aware reading library for papers, manuals, public metadata, and account-authorized ATP/ATPDraw material.

- `.aimora/cache/references/BooksPapers/` is a local ignored collection supplied by the repository owner on 2026-08-09. Its current intake contains 1,375 files and 77,254,002 bytes; the SHA-256 of the sorted relative-path content-hash inventory is `f09d8b6e30f4d19010138442f263fdcaa466d5c4198dd42a03377aed2a589022`, reproduced from that directory with `find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum`. Original acquisition URLs and redistribution rights are not established for the collection, so it is private reading material only. Before any item supports implementation or evidence, its exact title/version, source, relevant sections/equations, byte size, SHA-256, licence/restriction, and independent/copy boundary must be recorded in the canonical `AIMORAValidation` source dossier.

Reference material is not production code. A paper, ATP deck, or compiled result may motivate an implementation or act as an external oracle, but Julia owns every shipped AIMORA model, state transition, solver path, and result.
