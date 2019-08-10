# Generic Modelsim Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

MODELSIM_VLOG       = vlog
MODELSIM_VSIM       = vsim

VLOG_FLAGS      = -lint +cover $(foreach dir,$(INCLUDE_DIRS),+incdir+$(dir))
VSIM_FLAGS      = -t ps

GTKWAVE         = gtkwave

help::
	@echo "modelsim_sim - simulate design with modelsim in console mode"
	@echo "modelsim_simgui - simulate the design with modelsim in the gui mode"
	@echo "modelsim_build - elaborate the design"
	@echo "modelsim_xilinx_build - elaborate the design synthesized by xilinx vivado"
	@echo "modelsim_work - map the work library"

modelsim_sim: modelsim_build
	$(MODELSIM_VSIM) -c -do 'run -all' $(VSIM_FLAGS) $(TESTBENCH_MODULE)

modelsim_simgui: modelsim_build
	$(MODELSIM_VSIM) -do 'run -all' $(VSIM_FLAGS) -coverage $(TESTBENCH_MODULE)

modelsim_build: modelsim_work $(TESTBENCH_FILE) $(TOP_FILE) $(TOP_DEPS) $(TESTBENCH_DEPS)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(sort $(TOP_DEPS) $(TESTBENCH_DEPS) $(TOP_FILE) $(TESTBENCH_FILE))

modelsim_xilinx_build: modelsim_work $(TESTBENCH_FILE) $(POST_SYNTH_FILE) $(TESTBENCH_DEPS)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(TESTBENCH_DEPS) $(TESTBENCH_FILE) $(POST_SYNTH_FILE)

modelsim_work:
	vlib work
	vmap work work

clean:: modelsim_clean

modelsim_clean:
	rm -rf dataset.* compile library.cfg work *.ini transcript *.wlf
