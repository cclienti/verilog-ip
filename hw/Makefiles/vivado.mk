# Generic Xilinx Compilation with a Non-Project Flow
# Copyright (C) 2013-2014 Christophe Clienti - All Rights Reserved

VIVADO             ?= vivado
VIVADO_BIN         := $(shell which $(VIVADO) 2>/dev/null)
VIVADO_INSTALL_DIR := $(realpath $(dir $(VIVADO_BIN))/..)
GLBL_SRC           := $(VIVADO_INSTALL_DIR)/data/verilog/src/glbl.v

VIVADO_TOP_MODULE      ?= $(TOP_MODULE)
VIVADO_PROJECT_NAME    ?= $(VIVADO_TOP_MODULE)
VIVADO_PART            ?= "xc7z020clg484-1"
VIVADO_SYNTH_OPTIONS   ?= -flatten_hierarchy full -no_iobuf
VIVADO_BOARDFILE       ?= ../../../boards/zedboard/zedboard.xdc

.PHONY: vivado-gen-post-syn.tcl vivado-gen-post-impl.tcl

help::
	@echo "vivado-gen-post-impl - place & route using the vivado implementation flow (VIVADO_PART=$(VIVADO_PART))"
	@echo "vivado-gen-post-syn - synthesize using the vivado synthesizer (VIVADO_PART=$(VIVADO_PART))"

vivado-project: vivado-project.tcl
	mkdir -p vivado-project
	cd vivado-project && vivado -mode batch -source ../$^ -tclargs $(VIVADO_PROJECT_NAME) $(VIVADO_TOP_MODULE) $(VIVADO_PART)

vivado-project.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script to create project" > $@
	@echo "create_project $(TOP_MODULE) . -part $(VIVADO_PART) -force" >> $@
	@echo "add_files {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@echo "set_property top $(TOP_MODULE) [current_fileset]"
	@echo "add_files -fileset constrs_1 $(abspath $(VIVADO_BOARDFILE))" >> $@
	@echo "close_project -quiet" >> $@

vivado-gen-post-syn: vivado-gen-post-syn.tcl
	mkdir -p vivado-post-syn
	cd vivado-post-syn && vivado -mode batch -source ../$^ -notrace -nolog -nojournal
	cp -f $(GLBL_SRC) vivado-post-syn/glbl.v

vivado-gen-post-syn.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script for post synthesis simulation" > $@
	@echo "read_verilog {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@echo "synth_design -top $(TOP_MODULE) -part $(VIVADO_PART) $(VIVADO_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $@
	@echo "write_verilog -force -include_xilinx_libs -mode funcsim $(TOP_MODULE)_syn.v" >> $@
	@if [ -n "$(VIVADO_BOARDFILE)" ] && [ -f "$(VIVADO_BOARDFILE)" ]; then echo "read_xdc $(abspath $(VIVADO_BOARDFILE))" >> $@; fi
	@echo "report_utilization -file post_synth_util.rpt" >> $@
	@echo "report_timing_summary -file post_synth_timing.rpt" >> $@
	@echo "exit" >> $@

vivado-gen-post-impl: vivado-gen-post-impl.tcl
	mkdir -p vivado-post-impl
	cd vivado-post-impl && vivado -mode batch -source ../$^ -notrace -nolog -nojournal
	cp -f $(GLBL_SRC) vivado-post-impl/glbl.v

vivado-gen-post-impl.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script for post implementation simulation" > $@
	@echo "read_verilog {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@echo "synth_design -top $(TOP_MODULE) -part $(VIVADO_PART) $(VIVADO_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $@
	@if [ -n "$(VIVADO_BOARDFILE)" ] && [ -f "$(VIVADO_BOARDFILE)" ]; then echo "read_xdc $(abspath $(VIVADO_BOARDFILE))" >> $@; fi
	@echo "opt_design" >> $@
	@echo "place_design" >> $@
	@echo "route_design" >> $@
	@echo "phys_opt_design" >> $@
	@echo "write_checkpoint -force $(TOP_MODULE)_impl.dcp" >> $@
	@echo "write_verilog -force -include_xilinx_libs -mode timesim -sdf_anno true $(TOP_MODULE)_impl.v" >> $@
	@echo "report_utilization -file post_impl_util.rpt" >> $@
	@echo "report_timing_summary -file post_impl_timing.rpt" >> $@
	@echo "exit" >> $@

.PHONY: vivado-floorplan
vivado-floorplan:
	vivado vivado-post-impl/$(TOP_MODULE)_impl.dcp

help::
	@echo "vivado-floorplan       - open post-implementation floorplan in Vivado GUI"

clean:: vivado_clean

vivado_clean:
	rm -rf .Xil vivado vivado-* vivado.*
