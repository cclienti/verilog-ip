# Generic Yosys Makefile
# Copyright (C) 2016 Christophe Clienti - All Rights Reserved

YOSYS ?= yosys

YOSYS_SYNTHESIZE_DIR     = yosys
YOSYS_SYNTHESIZE_SCRIPT  = $(YOSYS_SYNTHESIZE_DIR)/yosys_synth.txt
YOSYS_SYNTHESIZED_FILE   = $(YOSYS_SYNTHESIZE_DIR)/$(TOP_MODULE).v

help::
	@echo "yosys_synth - synthesize using the yosys"
	@echo "yosys_icarus_vcd - simulate the synthesized design with yosys"

yosys_icarus_vcd: yosys_synth
	$(MAKE) TOP_FILE=$(YOSYS_SYNTHESIZED_FILE) TOP_MODULE= vcd

yosys_synth: $(YOSYS_SYNTHESIZED_FILE)

$(YOSYS_SYNTHESIZED_FILE): $(YOSYS_SYNTHESIZE_SCRIPT)
	$(YOSYS) -s $(YOSYS_SYNTHESIZE_SCRIPT)
	sed -i 's/(\*.*\*)[ ]*//g' $(YOSYS_SYNTHESIZED_FILE)
	sed -i '/^[ \t]*$$/d' $(YOSYS_SYNTHESIZED_FILE)

$(YOSYS_SYNTHESIZE_SCRIPT): $(TOP_FILE) $(TOP_DEPS)
	@mkdir -p $(YOSYS_SYNTHESIZE_DIR)
	@echo "Generating the yosys synth script"
	@echo "read_verilog $(TOP_FILE)" > $@
	@for v in $(TOP_DEPS); do echo "read_verilog $$v" >> $@; done
	@echo "$$YOSYS_TEMPLATE_SYNTHESIZE_SCRIPT" >> $@

clean:: yosys_clean

yosys_clean:
	rm -rf yosys


# ----------------------
# Yosys template scripts
# ----------------------

define YOSYS_TEMPLATE_SYNTHESIZE_SCRIPT
hierarchy -check -top $(TOP_MODULE)




write_verilog $(YOSYS_SYNTHESIZED_FILE)
endef
export YOSYS_TEMPLATE_SYNTHESIZE_SCRIPT
