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

# -sv holds every source to the SystemVerilog the rest of the flow
# compiles: iverilog builds everything as -g2012, but vlog decides the
# language by file extension, so the .v benches written against that
# level fail here as Verilog-2001 -- "Declarations not allowed in
# unnamed block" on dpmemrf_tb, and ten more like it.
VLOG_FLAGS         += -sv -lint $(MODELSIM_COVER_VLOG) $(foreach DIR,$(ALL_TOP_FILES),+incdir+$(dir $(DIR)))
VSIM_FLAGS         += -t ps $(foreach PARAM,$(TESTBENCH_PARAMS),-G $(PARAM))

GTKWAVE            ?= gtkwave
SURFER             ?= surfer

# vsim's native wave format is wlf, which no external viewer reads. For
# the external-viewer targets below the dump is a VCD, driven from the do
# script: the bench needs no $dumpvars of its own, the same policy as the
# iverilog flow.
VCD_FILE           ?= $(TESTBENCH_MODULE).vcd
MODELSIM_VCD_DO     = vcd file $(VCD_FILE); vcd add -r /$(TESTBENCH_MODULE)/*;

.PHONY: sim.modelsim check.modelsim trace.modelsim build.modelsim
.PHONY: trace.modelsim-gtkwave trace.modelsim-surfer
.PHONY: build-post-syn.modelsim work.modelsim clean.modelsim

HELP_ENTRIES += 'check.modelsim|simulate in console mode, fail on any error or a missing verdict'
HELP_ENTRIES += 'sim.modelsim|simulate the design in console mode'
HELP_ENTRIES += 'trace.modelsim|simulate the design in the gui mode with waveforms'
HELP_ENTRIES += 'trace.modelsim-gtkwave|simulate with modelsim, then show the VCD with gtkwave'
HELP_ENTRIES += 'trace.modelsim-surfer|simulate with modelsim, then show the VCD with surfer'
HELP_ENTRIES += 'build.modelsim|elaborate the design'
HELP_ENTRIES += 'build-post-syn.modelsim|elaborate the post-synthesis netlist'
HELP_ENTRIES += 'work.modelsim|map the work library'

sim.modelsim: build.modelsim
	$(MODELSIM_VSIM) -c -do 'run -all' $(VSIM_FLAGS) $(TESTBENCH_MODULE)

# The same generated view as the iverilog trace targets, built from the
# VCD this flow just wrote. wavedisp is invoked directly rather than
# through its make rule: that rule depends on sim.iverilog and reads
# $(DUMP_FILE), and overriding the latter to the VCD would have vvp
# write FST content into a file named .vcd -- the exact name/content
# disagreement the dump handling exists to prevent.
#
# A failed generation must not cost the viewer: on a mismatch the check
# reports and gtkwave falls back to the tcl script, which names no dump
# and always loads.
trace.modelsim-gtkwave: build.modelsim
	$(MODELSIM_VSIM) -c -do '$(MODELSIM_VCD_DO) run -all; quit -f' $(VSIM_FLAGS) $(TESTBENCH_MODULE)
	@view=""; \
	if [ -n "$(WAVEDISP_GTKWAVE_SAV)" ]; then \
	  $(MAKE) --no-print-directory venv.wavedisp >/dev/null; \
	  if $(WAVEDISP_BIN) -D $(VCD_FILE) -t gtkwave-savefile -o $(WAVEDISP_GTKWAVE_SAV) $(WAVEDISP_FILE) $(WAVEDISP_KWARGS); then \
	    view="-a $(WAVEDISP_GTKWAVE_SAV)"; \
	  else \
	    echo "$(WAVEDISP_FILE): does not match the dump, opening with the tcl script instead"; \
	    $(MAKE) --no-print-directory $(WAVEDISP_GTKWAVE_TCL) && view="-S $(WAVEDISP_GTKWAVE_TCL)"; \
	  fi; \
	fi; \
	$(GTKWAVE) $$view $(VCD_FILE)

trace.modelsim-surfer: build.modelsim
	$(MODELSIM_VSIM) -c -do '$(MODELSIM_VCD_DO) run -all; quit -f' $(VSIM_FLAGS) $(TESTBENCH_MODULE)
	$(if $(WAVEDISP_SURFER_FILE),$(MAKE) $(WAVEDISP_SURFER_FILE) WAVEDISP_DUMP=$(VCD_FILE) \
	    || $(MAKE) $(WAVEDISP_SURFER_FILE))
	$(SURFER) $(VCD_FILE) $(SURFER_COMMANDS)

# The same verdict rule as check.iverilog, but the failure predicate
# cannot be the same: vsim ends every run, passing ones included, with an
# "Errors: 0, Warnings: N" line, so grepping for the bare word would fail
# everything. What is matched instead is vsim's own "** Error" prefix --
# which $error and assertion failures print -- and the bench verdicts.
# quit -f because in batch mode $finish returns to the vsim prompt, and a
# captured run would sit there waiting on stdin.
check.modelsim: build.modelsim
	@out=$$($(MODELSIM_VSIM) -c -do 'run -all; quit -f' $(VSIM_FLAGS) $(TESTBENCH_MODULE) 2>&1); status=$$?; \
	echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -qE '\*\* (Error|Fatal)|[1-9][0-9]* ERROR\(S\)|FAIL'; then \
	  echo "$(TESTBENCH_MODULE): FAILED"; exit 1; fi; \
	if ! echo "$$out" | grep -qiE 'ALL TESTS PASSED|PASS:'; then \
	  echo "$(TESTBENCH_MODULE): NO VERDICT - reported neither success nor failure"; \
	  exit 1; fi

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

# The same action as sim-post-syn.iverilog, run by this vendor:
# elaborate the netlist vivado-gen-post-syn produced.
build-post-syn.modelsim: work.modelsim $(POST_SYNTH_FILE) $(ALL_TEST_FILES)
	$(MODELSIM_VLOG) $(VLOG_FLAGS) $(POST_SYNTH_FILE) $(ALL_TEST_FILES)

work.modelsim:
	$(MODELSIM_VLIB) work
	$(MODELSIM_VMAP) work work

clean:: clean.modelsim

clean.modelsim:
	rm -rf dataset.* compile library.cfg work *.ini transcript *.wlf $(VCD_FILE)
