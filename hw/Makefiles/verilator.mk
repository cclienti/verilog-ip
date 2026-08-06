# Generic Verilator Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

VERILATOR_MK_DIR   := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

# Every target uses the same pinned Verilator, run from a micromamba
# prefix environment local to the repository and created on first use:
# --timing needs at least 5.050 to behave, and distributions lag (Fedora
# ships 5.046). A prefix (-p) needs no mamba root and no activation,
# which is also what lets this run unchanged on a github action runner.
# Override VERILATOR to use another install.
MAMBA                  ?= micromamba
VERILATOR_MIN_VERSION  ?= 5.050
VERILATOR_ENV_DIR      ?= $(VERILATOR_MK_DIR)/.verilator-env
VERILATOR_ENV_BIN       = $(VERILATOR_ENV_DIR)/bin/verilator
VERILATOR              ?= $(MAMBA) run -p $(VERILATOR_ENV_DIR) verilator

VERILATOR_LIB_DIR   ?= verilator/lib
VERILATOR_CHECK_DIR ?= verilator/check
VERILATOR_LIB        = $(VERILATOR_LIB_DIR)/V$(TOP_MODULE)__ALL.a
VERILATOR_MAKE       = V$(TOP_MODULE).mk

# Warnings a project waives, by name -- set VERILATOR_WNO in the project
# Makefile and every verilator target honours it, lint included.
# MULTIDRIVEN on a dual-port memory is the archetype: both ports write
# the same ram by design. For file- or line-precise waivers, verilator
# also reads a .vlt configuration file listed among the sources.
VERILATOR_WNO       ?=

# Shared by every invocation: the waivers, the include paths, and the
# parameter overrides -- NAME=VALUE forwarded to the top module as
# -GNAME=VALUE, mirroring iverilog.mk (-P) and modelsim.mk (-G).
VERILATOR_COMMON_FLAGS  = $(addprefix -Wno-,$(VERILATOR_WNO))
VERILATOR_COMMON_FLAGS += $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VERILATOR_COMMON_FLAGS += $(foreach PARAM,$(TESTBENCH_PARAMS),-G$(PARAM))

VERILATOR_FLAGS     += $(VERILATOR_COMMON_FLAGS) -Mdir $(VERILATOR_LIB_DIR)

# check.verilator runs the testbench itself, with --timing to honour the
# delays and event controls a bench is made of. -Wno-fatal because the
# benches trip lint-class warnings and check's job is to run them, not
# to lint them -- lint.verilator does that; the warnings still print.
VERILATOR_CHECK_FLAGS  += $(VERILATOR_COMMON_FLAGS)
VERILATOR_CHECK_FLAGS  += --binary --timing -j 0 -Wno-fatal -Mdir $(VERILATOR_CHECK_DIR)

.PHONY: build.verilator lint.verilator check.verilator env.verilator version.verilator clean.verilator

HELP_ENTRIES += 'build.verilator|build the design with verilator'
HELP_ENTRIES += 'lint.verilator|lint the design with verilator'
HELP_ENTRIES += 'check.verilator|run the testbench under verilator --timing, fail on any error or a missing verdict'
HELP_ENTRIES += 'env.verilator|create the micromamba env holding verilator >= $(VERILATOR_MIN_VERSION)'

build.verilator: $(VERILATOR_LIB)

# Two rebuild traps on a file target: the directory's mtime moves every
# time a file lands in it, so it is order-only; and version.verilator is
# phony, and a phony prerequisite marks a file target permanently out of
# date, so the guard runs from the recipe instead.
$(VERILATOR_LIB): $(ALL_TOP_FILES) | $(VERILATOR_LIB_DIR)
	@$(MAKE) --no-print-directory version.verilator
	$(VERILATOR) $(VERILATOR_FLAGS) --cc $(ALL_TOP_FILES) --top-module $(TOP_MODULE)
	# The archive is named explicitly -- the generated makefile's default
	# target stops at the objects -- and the sub-make runs inside the env:
	# the generated rules write the compiler as an absolute path but reach
	# the archiver through PATH, and only the env holds the conda-prefixed
	# ar.
	$(MAMBA) run -p $(VERILATOR_ENV_DIR) $(MAKE) -C $(VERILATOR_LIB_DIR) -f $(VERILATOR_MAKE) $(notdir $(VERILATOR_LIB))

lint.verilator: version.verilator $(ALL_TOP_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $(ALL_TOP_FILES) --top-module $(TOP_MODULE)

$(VERILATOR_ENV_BIN):
	# binutils comes along because verilator's generated makefiles archive
	# with the conda toolchain's prefixed ar, which the verilator package
	# pulls the compiler for but not the archiver.
	$(MAMBA) create -y -p $(VERILATOR_ENV_DIR) -c conda-forge 'verilator>=$(VERILATOR_MIN_VERSION)' binutils

env.verilator: $(VERILATOR_ENV_BIN)

# Whatever VERILATOR resolves to -- the pinned env by default, an
# override, or a stray environment variable, which ?= silently obeys --
# must be at least VERILATOR_MIN_VERSION. Every verilator target runs
# through this guard, so a wrong version fails loudly, naming the
# command it resolved, instead of linting or simulating with it. The env
# is only created when VERILATOR actually points into it.
version.verilator: $(if $(findstring $(VERILATOR_ENV_DIR),$(VERILATOR)),$(VERILATOR_ENV_BIN))
	@v=$$($(VERILATOR) --version 2>/dev/null | awk '{print $$2}'); \
	if [ -z "$$v" ]; then \
	  echo "verilator not runnable via: $(VERILATOR)"; exit 1; fi; \
	if [ "$$(printf '%s\n' $(VERILATOR_MIN_VERSION) $$v | sort -V | head -1)" != "$(VERILATOR_MIN_VERSION)" ]; then \
	  echo "verilator $$v is older than the required $(VERILATOR_MIN_VERSION) (resolved: $(VERILATOR))"; \
	  exit 1; fi

# The same verdict rule as check.iverilog: fail on any reported error,
# fail on a missing verdict. Verilator's own runtime messages fit the
# predicate -- $error prints "%Error", and the simulation report lines
# contain neither word.
check.verilator: version.verilator $(ALL_SOURCE_FILES)
	@mkdir -p $(VERILATOR_CHECK_DIR)
	$(VERILATOR) $(VERILATOR_CHECK_FLAGS) --top-module $(TESTBENCH_MODULE) $(ALL_SOURCE_FILES)
	@out=$$(./$(VERILATOR_CHECK_DIR)/V$(TESTBENCH_MODULE) 2>&1); status=$$?; \
	echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -qiE 'error|fail'; then \
	  echo "$(TESTBENCH_MODULE): FAILED"; exit 1; fi; \
	if ! echo "$$out" | grep -qiE 'ALL TESTS PASSED|PASS:'; then \
	  echo "$(TESTBENCH_MODULE): NO VERDICT - reported neither success nor failure"; \
	  exit 1; fi

$(VERILATOR_LIB_DIR):
	mkdir -p $(VERILATOR_LIB_DIR)

clean:: clean.verilator

# Only what this file builds. verilator/ also holds hand-written C++
# testbenches kept in the repository -- hynoc_router_5p has four of
# them -- and removing the whole directory deleted them. The micromamba
# environment is shared by every project and is not removed here; drop
# it with `$(MAMBA) env remove -p $(VERILATOR_ENV_DIR)`.
clean.verilator:
	rm -rf $(VERILATOR_LIB_DIR) $(VERILATOR_CHECK_DIR)
	@rmdir $(patsubst %/,%,$(dir $(VERILATOR_LIB_DIR))) 2>/dev/null || true
