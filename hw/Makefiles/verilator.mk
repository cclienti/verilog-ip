# Generic Verilator Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

VERILATOR_LIB_DIR = verilator/lib

VERILATOR = verilator -Mdir $(VERILATOR_LIB_DIR) $(foreach dir,$(INCLUDE_DIRS),+incdir+$(dir))

VLIB  = $(join $(join obj_dir/V,$(TOP_MODULE)),__ALL.a)
VMAKE = $(join $(join V,$(TOP_MODULE)),.mk)

help::
	@echo "verilates - build the design with verilator"
	@echo "lint - lint the design with verilator"

verilates: $(VLIB)

$(VLIB): $(TOP_DEPS) $(TOP_FILE) $(VERILATOR_LIB_DIR)
	$(VERILATOR) --cc $(TOP_DEPS) $(TOP_FILE) --top-module $(TOP_MODULE)
	$(MAKE) -C $(VERILATOR_LIB_DIR) -f $(VMAKE)

lint: $(TOP_DEPS) $(TOP_FILE)
	$(VERILATOR) --lint-only $(TOP_DEPS) $(TOP_FILE) --top-module $(TOP_MODULE)

$(VERILATOR_LIB_DIR):
	mkdir -p $(VERILATOR_LIB_DIR)

clean:: verilator_clean

verilator_clean:
	rm -rf verilator
