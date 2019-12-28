# Generic Modelsim Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

MODELSIM_VLOG      ?= vlog
MODELSIM_VSIM      ?= vsim

VLOG_FLAGS         += -lint +cover $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VSIM_FLAGS         += -t ps

GTKWAVE            ?= gtkwave
VCD_FILE           ?= $(TESTBENCH_MODULE).vcd


help::
	@echo "msim-sim - simulate design with modelsim in console mode"
	@echo "msim-simgui - simulate the design with modelsim in the gui mode"
	@echo "msim-build - elaborate the design"
	@echo "msim-xilinx_build - elaborate the design synthesized by xilinx vivado"
	@echo "msim-work - map the work library"

msim-sim: msim-build
	$(MODELSIM_VSIM) -c -do 'run -all' $(VSIM_FLAGS) $(TESTBENCH_MODULE)

msim-simgui: msim-build $(WAVEDISP_MSIM_TCL)
	$(MODELSIM_VSIM) -do 'do $(WAVEDISP_MSIM_TCL); run -all' \
	    $(VSIM_FLAGS) -coverage $(TESTBENCH_MODULE)

msim-build: msim-work $(ALL_SOURCE_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(ALL_SOURCE_FILES)

msim-xilinx_build: msim-work $(POST_SYNTH_FILE) $(ALL_TEST_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(POST_SYNTH_FILE) $(ALL_TEST_FILES)

msim-work:
	vlib work
	vmap work work

clean:: msim-clean

msim-clean:
	rm -rf dataset.* compile library.cfg work *.ini transcript *.wlf
