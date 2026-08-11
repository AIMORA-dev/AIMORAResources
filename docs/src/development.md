# Contributing

Each public AIMORA component is an independent repository with its own source,
tests, examples, documentation, and checks.

```bash
git clone https://github.com/AIMORA-dev/AIMORA.jl
cd AIMORA.jl
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Contribution rules

- Keep physical units, bases, assumptions, and study ownership explicit.
- Add capability-focused Julia tests for changed behavior.
- Update the relevant public documentation in the same change.
- Do not publish credentials, local paths, unpublished source, or internal
  qualification records.
- Treat the compiled historical package as an external reference, never as a
  production dependency.
