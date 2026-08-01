# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG           ?= iverilog
VVP                ?= vvp
IVSTD              ?= -g2012
IVFLAGS            += -Wall -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS            += $(foreach DIR,$(ALL_TOP_FILES),-I$(dir $(DIR)))
IVFLAGS            += $(foreach PARAM,$(TESTBENCH_PARAMS),-P$(TESTBENCH_MODULE).$(PARAM))
GTKWAVE            ?= gtkwave --rcvar "fontname_signals Monospace 10" --rcvar "fontname_waves Monospace 10"
# Icarus dumps FST natively (vvp -fst). The previous -lxt2 wrote LXT2
# into a file named .vcd: GTKWave sniffed the content and opened it, but
# Surfer and every other reader go by the extension and refused it.
#
# The move is for readers, not for size. Measured on smalldiv_tb:
# LXT2 1.10 MB, FST 1.41 MB, VCD 61.6 MB -- FST costs 28% more than the
# LXT2 it replaces, and still 44x less than a plain VCD.
DUMP_FILE          ?= $(TESTBENCH_MODULE).fst

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
POST_SYNTH_DUMP       ?= $(POST_SYNTH_TB_MODULE).fst
GLBL_FILE             ?= vivado-post-syn/glbl.v
IVFLAGS_SYN           := -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS_SYN           += -I$(dir $(POST_SYNTH_TB_FILE))

help::
	@echo "trace          - simulate design with iverilog and show the waveform with gtkwave"
	@echo "fst            - simulate the design with iverilog"
	@echo "fst-post-syn   - simulate post-synthesis netlist with iverilog"
	@echo "trace-post-syn - simulate post-synthesis netlist and show the waveform with gtkwave"

trace: fst $(WAVEDISP_GTKWAVE_TCL)
	$(GTKWAVE) -S $(WAVEDISP_GTKWAVE_TCL) $(DUMP_FILE)

fst: $(DUMP_FILE)

sim: $(DUMP_FILE)

# Kept so the old names keep working.
vcd: fst

check: $(TESTBENCH_MODULE)
	! $(VVP) ./$< -fst | grep Error

$(DUMP_FILE): $(TESTBENCH_MODULE)
	$(VVP) ./$< -fst

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES)
	$(IVERILOG) $(IVFLAGS) -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES)

# Post-synthesis targets
fst-post-syn: $(POST_SYNTH_DUMP)

vcd-post-syn: fst-post-syn

trace-post-syn: $(POST_SYNTH_DUMP) $(WAVEDISP_GTKWAVE_TCL)
	$(GTKWAVE) -S $(WAVEDISP_GTKWAVE_TCL) $(POST_SYNTH_DUMP)

$(POST_SYNTH_DUMP): $(POST_SYNTH_TB_EXE)
	$(VVP) ./$< -fst

$(POST_SYNTH_TB_EXE): $(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE)
	$(IVERILOG) $(IVFLAGS_SYN) -s $(POST_SYNTH_TB_MODULE) -s glbl -o $(POST_SYNTH_TB_EXE) \
		$(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(DUMP_FILE) $(DUMP_FILE).hier $(TESTBENCH_MODULE)
	rm -rf $(POST_SYNTH_DUMP) $(POST_SYNTH_DUMP).hier $(POST_SYNTH_TB_EXE)
	# Leftover LXT2 dumps from before the switch, still named .vcd.
	rm -rf $(TESTBENCH_MODULE).vcd $(POST_SYNTH_TB_MODULE).vcd
