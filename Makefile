.PHONY: check test example clean-examples

JULIA ?= julia
EXAMPLES := $(sort $(dir $(wildcard examples/*/*/Makefile)))

check:
	$(JULIA) --project=. check.jl

test: check
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

example: check
	$(JULIA) --project=. examples/list_cases.jl
	@for example_dir in $(EXAMPLES); do \
		$(MAKE) --no-print-directory -C "$$example_dir" JULIA="$(JULIA)" run || exit $$?; \
	done

clean-examples:
	@for example_dir in $(EXAMPLES); do \
		$(MAKE) --no-print-directory -C "$$example_dir" clean || exit $$?; \
	done
