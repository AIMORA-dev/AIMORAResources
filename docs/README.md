# AIMORA Documentation

This repository builds the unified documentation website for [AIMORA.jl](https://github.com/AIMORA-dev/AIMORA.jl), a Julia platform for power and energy systems.

The documentation consumes an external `AIMORA.jl` checkout through `AIMORA_DOCS_ENGINE_PATH` or a sibling directory. It does not duplicate public packages as nested submodules.

## Structure

```text
src/                  public Markdown documentation
make.jl               Documenter build entrypoint
check.jl              links, structure, API, and publication-boundary checks
Makefile              local check and build commands
```

## Local build

```bash
git clone https://github.com/AIMORA-dev/AIMORAResources.git
git clone https://github.com/AIMORA-dev/AIMORA.jl.git
cd AIMORAResources/docs
julia --project=. -e 'using Pkg; Pkg.instantiate()'
make check
make build
```

Open `build/index.html`. GitHub Actions publishes the same build from the consolidated Resources repository.

Place both clones in the same parent directory, or set `AIMORA_DOCS_ENGINE_PATH` explicitly. Only public repositories and public product information are inputs to this website. Internal source, repository names, paths, validation records, and development instructions are rejected by `check.jl`.

## Licence

This repository's AIMORA-authored content is distributed under the PolyForm Noncommercial License 1.0.0. Research, education, personal study, public-interest noncommercial use, and other purposes permitted by that licence are free; commercial use requires a separate written agreement with Ahmed Elkholy <ahmed_elkholy@f-eng.tanta.edu.eg>. There is no licence key, activation, telemetry, or technical feature restriction. Clearly identified third-party material retains its own terms, and copies received under an earlier licence retain those prior grants.
