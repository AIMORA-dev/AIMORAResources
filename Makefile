.PHONY: check test example example-changed example-selected release clean-examples

JULIA ?= julia
EXAMPLES := $(sort $(dir $(wildcard examples/*/*/Makefile)))

check:
	$(JULIA) --project=. check.jl

test: check
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

example: check
	$(JULIA) --project=. examples/list_cases.jl
	JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
		$(JULIA) --project=. examples/run_examples.jl --all --release
	$(JULIA) --project=. check.jl

example-changed:
	@test -n "$(CHANGED_PATHS)" || { echo "CHANGED_PATHS is required" >&2; exit 2; }
	$(JULIA) --project=. examples/run_examples.jl --changed $(CHANGED_PATHS)

example-selected:
	@test -n "$(EXAMPLE_IDS)" || { echo "EXAMPLE_IDS is required" >&2; exit 2; }
	$(JULIA) --project=. examples/run_examples.jl $(foreach id,$(EXAMPLE_IDS),--id $(id))

release: test example

clean-examples:
	@for example_dir in $(EXAMPLES); do \
		$(MAKE) --no-print-directory -C "$$example_dir" clean || exit $$?; \
	done
