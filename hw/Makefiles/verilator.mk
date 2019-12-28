# Generic Verilator Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

VERILATOR          ?= verilator
VERILATOR_FLAGS    += -Mdir $(VERILATOR_LIB_DIR) $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VERILATOR_LIB_DIR  ?= verilator/lib

VERILATOR_LIB       = $(join $(join obj_dir/V,$(TOP_MODULE)),__ALL.a)
VERILATOR_MAKE      = $(join $(join V,$(TOP_MODULE)),.mk)


help::
	@echo "verilates - build the design with verilator"
	@echo "lint - lint the design with verilator"

verilates: $(VERILATOR_LIB)

$(VERILATOR_LIB): $(ALL_TOP_FILES) $(VERILATOR_LIB_DIR)
	$(VERILATOR) $(VERILATOR_FLAGS) --cc $(ALL_TOP_FILES) --top-module $(TOP_MODULE)
	$(MAKE) -C $(VERILATOR_LIB_DIR) -f $(VERILATOR_MAKE)

lint: $(ALL_TOP_FILES)
	$(VERILATOR) $(VERILATOR_FLAGS) --lint-only $(ALL_TOP_FILES) --top-module $(TOP_MODULE)

$(VERILATOR_LIB_DIR):
	mkdir -p $(VERILATOR_LIB_DIR)

clean:: verilator_clean

verilator_clean:
	rm -rf verilator
