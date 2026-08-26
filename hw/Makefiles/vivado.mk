# Generic Xilinx Compilation with a Non-Project Flow
# Copyright (C) 2013-2014 Christophe Clienti - All Rights Reserved

# Where the tool lives. Empty by default, so the bare name goes through
# PATH. Vivado is usually not on PATH, so either put it there --
#
#   export PATH="$HOME/Xilinx/2025.1/Vivado/bin:$PATH"
#
# -- or set VIVADO_BIN_DIR, on the command line or exported from a shell
# rc, which make imports as a variable of the same name.
#
# abspath, not a plain join: three of the recipes below cd into their
# output directory first, so a relative prefix would no longer resolve.
# It also absorbs a trailing slash.
VIVADO_BIN_DIR     ?=
VIVADO_PREFIX       = $(if $(VIVADO_BIN_DIR),$(abspath $(VIVADO_BIN_DIR))/)
VIVADO             ?= $(VIVADO_PREFIX)vivado

# The resolved executable, used only to find glbl.v inside the install.
# `which` hands back an absolute path unchanged, so this works whether the
# name came from PATH or from VIVADO_BIN_DIR.
VIVADO_EXE         := $(shell which $(VIVADO) 2>/dev/null)
VIVADO_INSTALL_DIR := $(realpath $(dir $(VIVADO_EXE))/..)
GLBL_SRC           := $(VIVADO_INSTALL_DIR)/data/verilog/src/glbl.v

VIVADO_TOP_MODULE      ?= $(TOP_MODULE)
VIVADO_PROJECT_NAME    ?= $(VIVADO_TOP_MODULE)
VIVADO_PART            ?= "xc7z020clg484-1"
VIVADO_SYNTH_OPTIONS   ?= -flatten_hierarchy full -no_iobuf

# Anchored to this makefile's own location rather than a depth-relative
# path: projects include vivado.mk from three levels down (hw/lib) or
# four (hw/network/<family>), and a ../../../ default silently resolved
# to a nonexistent file for the deeper ones, running them unconstrained.
# Pure make, so it also works outside a git checkout.
VIVADO_MK_DIR          := $(dir $(lastword $(MAKEFILE_LIST)))
VIVADO_BOARDFILE       ?= $(abspath $(VIVADO_MK_DIR)../boards/zedboard/zedboard.xdc)

# Set to 1 for module-level (out-of-context) projects: synth_1 runs with
# -mode out_of_context, so no IOBUFs are inserted and implementation does
# not require pin placement (the project-mode equivalent of -no_iobuf,
# which only applies to the non-project vivado-gen-* targets).
VIVADO_PROJECT_OOC     ?= 0

.PHONY: vivado-project.tcl vivado-gen-post-syn.tcl vivado-gen-post-impl.tcl
.PHONY: project.vivado synth.vivado impl.vivado floorplan.vivado
.PHONY: clean.vivado distclean.vivado

HELP_ENTRIES += 'project.vivado|generate the vivado project'
HELP_ENTRIES += 'synth.vivado|synthesize the design (VIVADO_PART=$(VIVADO_PART))'
HELP_ENTRIES += 'impl.vivado|place & route the design (VIVADO_PART=$(VIVADO_PART))'

project.vivado: vivado-project.tcl
	mkdir -p vivado-project
	cd vivado-project && $(VIVADO) -mode batch -source ../$^ -tclargs $(VIVADO_PROJECT_NAME) $(VIVADO_TOP_MODULE) $(VIVADO_PART)

vivado-project.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script to create project" > $@
	@echo "create_project $(TOP_MODULE) . -part $(VIVADO_PART) -force" >> $@
	@echo "add_files {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@echo "set_property top $(TOP_MODULE) [current_fileset]" >> $@
	@if [ -n "$(VIVADO_BOARDFILE)" ] && [ -f "$(VIVADO_BOARDFILE)" ]; then \
		echo "add_files -fileset constrs_1 $(abspath $(VIVADO_BOARDFILE))" >> $@; \
	else \
		echo 'puts "WARNING: boardfile $(VIVADO_BOARDFILE) not found: project has NO constraints"' >> $@; \
	fi
	@if [ "$(VIVADO_PROJECT_OOC)" = "1" ]; then \
		echo "set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]" >> $@; \
	fi
	@echo "close_project -quiet" >> $@

synth.vivado: vivado-gen-post-syn.tcl
	mkdir -p vivado-post-syn
	cd vivado-post-syn && $(VIVADO) -mode batch -source ../$^ -notrace -nolog -nojournal
	cp -f $(GLBL_SRC) vivado-post-syn/glbl.v

vivado-gen-post-syn.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script for post synthesis simulation" > $@
	@echo "read_verilog {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@if [ -n "$(VIVADO_BOARDFILE)" ] && [ -f "$(VIVADO_BOARDFILE)" ]; then \
		echo "read_xdc $(abspath $(VIVADO_BOARDFILE))" >> $@; \
	else \
		echo 'puts "WARNING: boardfile $(VIVADO_BOARDFILE) not found: running UNCONSTRAINED, timing numbers are meaningless"' >> $@; \
	fi
	@echo "synth_design -top $(TOP_MODULE) -part $(VIVADO_PART) $(VIVADO_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $@
	@echo "write_verilog -force -include_xilinx_libs -mode funcsim $(TOP_MODULE)_syn.v" >> $@
	@echo "report_utilization -file post_synth_util.rpt" >> $@
	@echo "report_timing_summary -file post_synth_timing.rpt" >> $@
	@echo "exit" >> $@

impl.vivado: vivado-gen-post-impl.tcl
	mkdir -p vivado-post-impl
	cd vivado-post-impl && $(VIVADO) -mode batch -source ../$^ -notrace -nolog -nojournal
	cp -f $(GLBL_SRC) vivado-post-impl/glbl.v

vivado-gen-post-impl.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script for post implementation simulation" > $@
	@echo "read_verilog {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@if [ -n "$(VIVADO_BOARDFILE)" ] && [ -f "$(VIVADO_BOARDFILE)" ]; then \
		echo "read_xdc $(abspath $(VIVADO_BOARDFILE))" >> $@; \
	else \
		echo 'puts "WARNING: boardfile $(VIVADO_BOARDFILE) not found: running UNCONSTRAINED, timing numbers are meaningless"' >> $@; \
	fi
	@echo "synth_design -top $(TOP_MODULE) -part $(VIVADO_PART) $(VIVADO_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $@
	@echo "opt_design" >> $@
	@echo "place_design" >> $@
	@echo "route_design" >> $@
	@echo "phys_opt_design" >> $@
	@echo "write_checkpoint -force $(TOP_MODULE)_impl.dcp" >> $@
	@echo "write_verilog -force -include_xilinx_libs -mode timesim -sdf_anno true $(TOP_MODULE)_impl.v" >> $@
	@echo "report_utilization -file post_impl_util.rpt" >> $@
	@echo "report_timing_summary -file post_impl_timing.rpt" >> $@
	@echo "exit" >> $@

floorplan.vivado:
	$(VIVADO) vivado-post-impl/$(TOP_MODULE)_impl.dcp

HELP_ENTRIES += 'floorplan.vivado|open the post-implementation floorplan in the gui'

clean:: clean.vivado
distclean:: distclean.vivado

# Only what comes back in seconds: the scratch directory, the journals
# and logs, the jvm crash dumps, and the tcl scripts this file generates.
#
# The journals and logs are named rather than globbed: vivado.* also
# matched vivado.xdc, a constraint file kept in the repository, and
# clean deleted it. The same care applies to the directories -- the old
# `rm -rf vivado-*` here swept up vivado-post-syn along with them.
clean.vivado:
	rm -rf .Xil
	rm -f vivado.jou vivado.log vivado_*.backup.jou vivado_*.backup.log
	rm -f hs_err_pid*
	rm -f vivado-project.tcl vivado-gen-post-syn.tcl vivado-gen-post-impl.tcl

# The tool outputs: a netlist, a placed-and-routed checkpoint, a project.
# Rebuilding any of them costs a synthesis or an implementation run --
# minutes to hours -- so they do not belong beside a dump that takes two
# seconds. clean carrying them away is how a netlist got lost.
distclean.vivado:
	rm -rf vivado vivado-project vivado-post-syn vivado-post-impl
