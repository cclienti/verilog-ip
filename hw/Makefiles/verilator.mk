# Generic Verilator Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

VERILATOR          ?= verilator
VERILATOR_FLAGS    += -Mdir $(VERILATOR_LIB_DIR) $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
# Forward parameter overrides (NAME=VALUE) to the top module as -GNAME=VALUE,
# mirroring iverilog.mk (-P) and modelsim.mk (-G).
VERILATOR_FLAGS    += $(foreach PARAM,$(TESTBENCH_PARAMS),-G$(PARAM))
VERILATOR_LIB_DIR  ?= verilator/lib

VERILATOR_LIB       = $(VERILATOR_LIB_DIR)/V$(TOP_MODULE)__ALL.a
VERILATOR_MAKE      = V$(TOP_MODULE).mk


.PHONY: build.verilator lint.verilator clean.verilator

HELP_ENTRIES += 'build.verilator|build the design with verilator'
HELP_ENTRIES += 'lint.verilator|lint the design with verilator'

build.verilator: $(VERILATOR_LIB)

$(VERILATOR_LIB): $(ALL_TOP_FILES) $(VERILATOR_LIB_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --cc $(ALL_TOP_FILES) --top-module $(TOP_MODULE)
	$(MAKE) -C $(VERILATOR_LIB_DIR) -f $(VERILATOR_MAKE)

lint.verilator: $(ALL_TOP_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $(ALL_TOP_FILES) --top-module $(TOP_MODULE)

$(VERILATOR_LIB_DIR):
	mkdir -p $(VERILATOR_LIB_DIR)

clean:: clean.verilator

# Only what this file builds. verilator/ also holds hand-written C++
# testbenches kept in the repository -- hynoc_router_5p has four of
# them -- and removing the whole directory deleted them.
clean.verilator:
	rm -rf $(VERILATOR_LIB_DIR)
	@rmdir $(patsubst %/,%,$(dir $(VERILATOR_LIB_DIR))) 2>/dev/null || true
