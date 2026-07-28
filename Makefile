.PHONY: check build test example

JULIA ?= julia

check:
	$(JULIA) --project=. check.jl

build: check
	EMTP_DEBUG_BUILD=1 scripts/build_fortran.sh

test: check
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

example: build
	$(JULIA) --project=. examples/emt/rlc_energization/run.jl
