# Generic Modelsim Makefile
# Copyright (C) 2013 Christophe Clienti - All Rights Reserved

# Where the tools live. Empty by default, so the bare names go through
# PATH -- put the bin directory there and nothing else is needed.
#
# Otherwise set MODELSIM_BIN_DIR: on the command line, or exported in the
# environment, which make imports as a variable of the same name, so a
# line in your shell rc covers every project:
#
#   export MODELSIM_BIN_DIR=$HOME/intelFPGA/20.1/modelsim_ase/bin
#
# Each tool stays overridable on its own, for an install that mixes them
# or wraps one in a script.
MODELSIM_BIN_DIR   ?=
MODELSIM_PREFIX     = $(if $(MODELSIM_BIN_DIR),$(abspath $(MODELSIM_BIN_DIR))/)

MODELSIM_VLIB      ?= $(MODELSIM_PREFIX)vlib
MODELSIM_VMAP      ?= $(MODELSIM_PREFIX)vmap
MODELSIM_VLOG      ?= $(MODELSIM_PREFIX)vlog
MODELSIM_VSIM      ?= $(MODELSIM_PREFIX)vsim

# Code coverage is off by default because the free edition is not
# licensed for it: vsim answers "This product is not licensed for Code
# Coverage" and refuses to load the design, so trace.modelsim could never
# run on a ModelSim ASE install. vlog accepts +cover there without
# complaint, which is why the failure only ever showed at simulation.
# Set to 1 on an edition that carries the licence.
MODELSIM_COVERAGE  ?= 0
MODELSIM_COVER_VLOG = $(if $(filter 1,$(MODELSIM_COVERAGE)),+cover)
MODELSIM_COVER_VSIM = $(if $(filter 1,$(MODELSIM_COVERAGE)),-coverage)

# The bare `+` that used to sit after -t ps was passed straight through to
# vsim, which took it for an empty plusarg and ignored it.
VLOG_FLAGS         += -lint $(MODELSIM_COVER_VLOG) $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VSIM_FLAGS         += -t ps $(foreach PARAM,$(TESTBENCH_PARAMS),-G $(PARAM))

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
	    $(VSIM_FLAGS) $(MODELSIM_COVER_VSIM) $(TESTBENCH_MODULE)

build.modelsim: work.modelsim $(ALL_SOURCE_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(ALL_SOURCE_FILES)

# Was msim-xilinx_build, which hid that this is the same action as
# sim-post-syn.iverilog, run by another vendor.
build-post-syn.modelsim: work.modelsim $(POST_SYNTH_FILE) $(ALL_TEST_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(POST_SYNTH_FILE) $(ALL_TEST_FILES)

work.modelsim:
	$(MODELSIM_VLIB) work
	$(MODELSIM_VMAP) work work

clean:: clean.modelsim

clean.modelsim:
	rm -rf dataset.* compile library.cfg work *.ini transcript *.wlf
