# Generic Xilinx Compilation with a Non-Project Flow
# Copyright (C) 2013-2014 Christophe Clienti - All Rights Reserved

VIVADO_TOP_MODULE      ?= $(TOP_MODULE)
VIVADO_PROJECT_NAME    ?= $(VIVADO_TOP_MODULE)
VIVADO_PART            ?= "xc7z020clg484-1"
VIVADO_SYNTH_OPTIONS   ?= -flatten_hierarchy full -no_iobuf
VIVADO_BOARDFILE       ?= ../../../boards/zedboard/zedboard.xdc


help::
	@echo "vivado-gen-post-syn - synthesize using the vivado synthesizer (VIVADO_PART=$(VIVADO_PART))"

vivado-project: vivado-project.tcl
	mkdir -p vivado-project
	cd vivado && vivado -mode batch -source ../$^ -tclargs $(VIVADO_PROJECT_NAME) $(VIVADO_TOP_MODULE) $(VIVADO_PART)

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

vivado-gen-post-syn.tcl: $(ALL_TOP_FILES)
	@echo "Generating $@"
	@echo "### Vivado $(TOP_MODULE) script for post synthesis simulation" > $@
	@echo "read_verilog {" >> $@
	@for f in $(ALL_TOP_FILES); do echo "  $$f" >> $@; done
	@echo "}" >> $@
	@echo "synth_design -top $(TOP_MODULE) -part $(VIVADO_PART) $(VIVADO_SYNTH_OPTIONS) -include_dirs \"$(INCLUDE_DIRS)\"" >> $@
	@echo "write_verilog -force -include_xilinx_libs -mode funcsim $(TOP_MODULE)_syn.v" >> $@
	@echo "report_utilization -file post_synth_util.rpt" >> $@
	@echo "report_timing_summary -file post_synth_timing.rpt" >> $@
	@echo "exit" >> $@

clean:: vivado_clean

vivado_clean:
	rm -rf .Xil vivado vivado-* vivado.*
