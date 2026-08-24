JULIA ?= $(shell command -v julia 2>/dev/null || echo $(HOME)/.juliaup/bin/julia)
OUT ?= outputs

.PHONY: run clean

run:
	@test -n "$(AIMORA_SOLVER_PATH)" || { echo "AIMORA_SOLVER_PATH is required" >&2; exit 2; }
	$(JULIA) --project=../../.. run.jl $(OUT)

clean:
	rm -rf $(OUT)
