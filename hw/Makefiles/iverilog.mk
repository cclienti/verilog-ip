# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG           ?= iverilog
VVP                ?= vvp
IVSTD              ?= -g2012
IVFLAGS            += -Wall -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS            += $(foreach DIR,$(ALL_TOP_FILES),-I$(dir $(DIR)))
IVFLAGS            += $(foreach PARAM,$(TESTBENCH_PARAMS),-P$(TESTBENCH_MODULE).$(PARAM))
GTKWAVE            ?= gtkwave --rcvar "fontname_signals Monospace 10" --rcvar "fontname_waves Monospace 10"
VCD_FILE           ?= $(TESTBENCH_MODULE).vcd

# Post-synthesis simulation (netlist produced by vivado-gen-post-syn)
# POST_SYNTH_TB_FILE: dedicated testbench for the post-syn netlist (no param overrides).
# Defaults to <testbench_dir>/<testbench_module>_postsyn.sv if not set in project Makefile.
# GLBL_FILE: Xilinx glbl module (provides glbl.GSR used by FDRE/RAM primitives).
#            Copied from the Vivado installation into vivado-post-syn/ by vivado-gen-post-syn.
#            Override in the project Makefile if needed.
POST_SYNTH_FILE       ?= vivado-post-syn/$(TOP_MODULE)_syn.v
POST_SYNTH_TB_MODULE  ?= $(TESTBENCH_MODULE)_postsyn
POST_SYNTH_TB_FILE    ?= $(dir $(TESTBENCH_FILE))$(POST_SYNTH_TB_MODULE).sv
POST_SYNTH_TB_EXE     ?= $(POST_SYNTH_TB_MODULE)
POST_SYNTH_VCD        ?= $(POST_SYNTH_TB_MODULE).vcd
GLBL_FILE             ?= vivado-post-syn/glbl.v
IVFLAGS_SYN           := -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS_SYN           += -I$(dir $(POST_SYNTH_TB_FILE))

help::
	@echo "trace          - simulate design with iverilog and show the vcd with gtkwave"
	@echo "vcd            - simulate the design with iverilog"
	@echo "vcd-post-syn   - simulate post-synthesis netlist with iverilog"
	@echo "trace-post-syn - simulate post-synthesis netlist and show vcd with gtkwave"

trace: vcd $(WAVEDISP_GTKWAVE_TCL)
	$(GTKWAVE) -S $(WAVEDISP_GTKWAVE_TCL) $(VCD_FILE)

vcd: $(VCD_FILE)

sim: $(VCD_FILE)

check: $(TESTBENCH_MODULE)
	! $(VVP) ./$< -lxt2 | grep Error

$(VCD_FILE): $(TESTBENCH_MODULE)
	$(VVP) ./$< -lxt2

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES)
	$(IVERILOG) $(IVFLAGS) -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES)

# Post-synthesis targets
vcd-post-syn: $(POST_SYNTH_VCD)

trace-post-syn: $(POST_SYNTH_VCD) $(WAVEDISP_GTKWAVE_TCL)
	$(GTKWAVE) -S $(WAVEDISP_GTKWAVE_TCL) $(POST_SYNTH_VCD)

$(POST_SYNTH_VCD): $(POST_SYNTH_TB_EXE)
	$(VVP) ./$< -lxt2

$(POST_SYNTH_TB_EXE): $(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE)
	$(IVERILOG) $(IVFLAGS_SYN) -s $(POST_SYNTH_TB_MODULE) -s glbl -o $(POST_SYNTH_TB_EXE) \
		$(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(VCD_FILE) $(TESTBENCH_MODULE) $(POST_SYNTH_VCD) $(POST_SYNTH_TB_EXE)
