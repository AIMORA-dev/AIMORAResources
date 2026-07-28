.PHONY: check test example

JULIA ?= julia

check:
	$(JULIA) --project=. check.jl

test: check
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

example:
	$(JULIA) --project=. examples/list_assets.jl
