.PHONY: check build

JULIA ?= julia

check:
	$(JULIA) --project=. check.jl

build: check
	$(JULIA) --project=. make.jl
