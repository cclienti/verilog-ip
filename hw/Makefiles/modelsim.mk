# Generic Modelsim Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

MODELSIM_VLOG      ?= vlog
MODELSIM_VSIM      ?= vsim

VLOG_FLAGS         += -lint +cover $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VSIM_FLAGS         += -t ps + $(foreach PARAM,$(TESTBENCH_PARAMS),-G $(PARAM))

GTKWAVE            ?= gtkwave
VCD_FILE           ?= $(TESTBENCH_MODULE).vcd


.PHONY: sim.modelsim trace.modelsim build.modelsim build-post-syn.modelsim
.PHONY: work.modelsim clean.modelsim

HELP_ENTRIES += 'sim.modelsim|simulate the design in console mode'
HELP_ENTRIES += 'trace.modelsim|simulate the design in the gui mode with waveforms'
HELP_ENTRIES += 'build.modelsim|elaborate the design'
HELP_ENTRIES += 'build-post-syn.modelsim|elaborate the post-synthesis netlist'
HELP_ENTRIES += 'work.modelsim|map the work library'

sim.modelsim: build.modelsim
	$(MODELSIM_VSIM) -c -do 'run -all' $(VSIM_FLAGS) $(TESTBENCH_MODULE)

# The gui run is this vendor's viewer, so it is named like the others:
# `trace` is what you type when you want to look at waveforms, whichever
# tool draws them.
#
# The save script is built from the recipe rather than named as a
# prerequisite, and guarded on the variable: six project Makefiles include
# this file before wavedisp.mk, where WAVEDISP_MODELSIM_TCL is still
# empty, and prerequisites are expanded as the rule is read.
#
# The guard also decides the -do string. Without it a project that does
# not include wavedisp.mk gets `do ; run -all`, a do with no argument.
MODELSIM_WAVE_DO = $(if $(WAVEDISP_MODELSIM_TCL),do $(WAVEDISP_MODELSIM_TCL);)

trace.modelsim: build.modelsim
	$(if $(WAVEDISP_MODELSIM_TCL),$(MAKE) $(WAVEDISP_MODELSIM_TCL))
	$(MODELSIM_VSIM) -do '$(MODELSIM_WAVE_DO) run -all' \
	    $(VSIM_FLAGS) -coverage $(TESTBENCH_MODULE)

build.modelsim: work.modelsim $(ALL_SOURCE_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(ALL_SOURCE_FILES)

# Was msim-xilinx_build, which hid that this is the same action as
# sim-post-syn.iverilog, run by another vendor.
build-post-syn.modelsim: work.modelsim $(POST_SYNTH_FILE) $(ALL_TEST_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(POST_SYNTH_FILE) $(ALL_TEST_FILES)

work.modelsim:
	vlib work
	vmap work work

clean:: clean.modelsim

clean.modelsim:
	rm -rf dataset.* compile library.cfg work *.ini transcript *.wlf
