# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG_MK_DIR    := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))

IVERILOG           ?= iverilog
VVP                ?= vvp
IVSTD              ?= -g2012
IVFLAGS            += -Wall -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS            += $(foreach DIR,$(ALL_TOP_FILES),-I$(dir $(DIR)))
IVFLAGS            += $(foreach PARAM,$(TESTBENCH_PARAMS),-P$(TESTBENCH_MODULE).$(PARAM))
GTKWAVE            ?= gtkwave --rcvar "fontname_signals Monospace 10" --rcvar "fontname_waves Monospace 10"
SURFER             ?= surfer

# vvp takes the dump format from an extended argument or, in its absence,
# from IVERILOG_DUMPER. Deriving the file extension from that same
# variable is what keeps the two from ever disagreeing -- the bug behind
# this whole switch was a file named .vcd that held LXT2: GTKWave sniffed
# the content and opened it, Surfer and every other reader went by the
# extension and refused it.
#
# Exporting it also covers the invocations this makefile does not spell
# out: `vvp ./<tb>` typed by hand dumps FST too, as long as it inherits
# this environment. Put it in your shell rc to cover the rest.
#
# fst over lxt2 is for readers, not for size. Measured on smalldiv_tb:
# LXT2 1.10 MB, FST 1.41 MB, VCD 61.6 MB -- FST costs 28% more than the
# LXT2 it replaces, and still 44x less than a plain VCD.
#
# Only the bare format names work here (fst, lxt2, lxt, vcd). The tuned
# variants exist as extended arguments only: IVERILOG_DUMPER=fst-space is
# not recognised and silently falls back to VCD.
IVERILOG_DUMPER    ?= fst
export IVERILOG_DUMPER

ifeq ($(IVERILOG_DUMPER),none)
$(error IVERILOG_DUMPER=none suppresses every dump; use `make check` instead)
endif

DUMP_FILE          ?= $(TESTBENCH_MODULE).$(IVERILOG_DUMPER)

# Dump driver elaborated as a second root module, so that no testbench
# names its own dump file. See dumper.v.
DUMPER_FILE        ?= $(IVERILOG_MK_DIR)/dumper.v
DUMPER_MODULE      ?= wave_dumper

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
POST_SYNTH_DUMP       ?= $(POST_SYNTH_TB_MODULE).$(IVERILOG_DUMPER)
GLBL_FILE             ?= vivado-post-syn/glbl.v
IVFLAGS_SYN           := -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS_SYN           += -I$(dir $(POST_SYNTH_TB_FILE))

# gtkwave's -S takes the next word as a script. Handing it a dump file
# because no save script exists is how `make trace` ended up opening an
# empty window in the projects that do not include wavedisp.mk.
GTKWAVE_SCRIPT         = $(if $(WAVEDISP_GTKWAVE_TCL),-S $(WAVEDISP_GTKWAVE_TCL))

# Surfer replays a command file after loading the dump. Same guard: no
# save script, no option.
SURFER_COMMANDS        = $(if $(WAVEDISP_SURFER_FILE),--command-file $(WAVEDISP_SURFER_FILE))

# The RTL save script names scopes under $(TESTBENCH_MODULE), and the
# post-synthesis testbench has a different top, so loading it here would
# select nothing. Only a script written for this top is used.
POST_SYNTH_GTKWAVE_TCL ?= $(wildcard $(POST_SYNTH_TB_MODULE).gtkwave.tcl)
POST_SYNTH_GTKWAVE_SCRIPT = $(if $(POST_SYNTH_GTKWAVE_TCL),-S $(POST_SYNTH_GTKWAVE_TCL))

help::
	@echo "trace          - simulate design with iverilog and show the waveform with gtkwave"
	@echo "trace-surfer   - simulate design with iverilog and show the waveform with surfer"
	@echo "sim            - simulate the design with iverilog (aliases: fst, vcd)"
	@echo "check          - simulate without dumping, fail on any error reported"
	@echo "sim-post-syn   - simulate post-synthesis netlist with iverilog (aliases: fst-post-syn, vcd-post-syn)"
	@echo "trace-post-syn - simulate post-synthesis netlist and show the waveform with gtkwave"

# The save script is built from the recipe rather than named as a
# prerequisite: prerequisites are expanded as the rule is read, and the
# project Makefiles do not agree on whether wavedisp.mk comes before or
# after this one -- shmemif includes it after, where the variable is
# still empty and the script was silently never regenerated. A recipe is
# expanded late enough to see the variable either way.
#
# The whole recipe is expanded before its first line runs, so the option
# below cannot be guarded on the file existing: it is guarded on the
# variable, which is set exactly when wavedisp.mk is in play.
trace: sim
	$(if $(WAVEDISP_GTKWAVE_TCL),$(MAKE) $(WAVEDISP_GTKWAVE_TCL))
	$(GTKWAVE) $(GTKWAVE_SCRIPT) $(DUMP_FILE)

trace-surfer: sim
	$(if $(WAVEDISP_SURFER_FILE),$(MAKE) $(WAVEDISP_SURFER_FILE))
	$(SURFER) $(DUMP_FILE) $(SURFER_COMMANDS)

sim: $(DUMP_FILE)

# Kept so the old names keep working.
fst: sim
vcd: sim

# The dump is written and never read here, so suppress it entirely: it
# makes the long testbenches noticeably faster.
#
# Failures are reported as "Error", "error", "FAIL:" or "FAIL [", so the
# pattern has to cover more than the capital-E form -- grep Error alone
# let "FAIL: 3 error(s) found" through and reported success. No passing
# testbench prints either word.
check: $(TESTBENCH_MODULE)
	@out=$$(IVERILOG_DUMPER=none $(VVP) ./$< 2>&1); status=$$?; \
	echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -qiE 'error|fail'; then exit 1; fi

$(DUMP_FILE): $(TESTBENCH_MODULE)
	$(VVP) ./$<

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES) $(DUMPER_FILE)
	$(IVERILOG) $(IVFLAGS) \
		-DDUMP_FILE='"$(DUMP_FILE)"' -DDUMP_SCOPE=$(TESTBENCH_MODULE) \
		-s $(TESTBENCH_MODULE) -s $(DUMPER_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES) $(DUMPER_FILE)

# Post-synthesis targets
sim-post-syn: $(POST_SYNTH_DUMP)

fst-post-syn: sim-post-syn
vcd-post-syn: sim-post-syn

trace-post-syn: $(POST_SYNTH_DUMP)
	$(GTKWAVE) $(POST_SYNTH_GTKWAVE_SCRIPT) $(POST_SYNTH_DUMP)

$(POST_SYNTH_DUMP): $(POST_SYNTH_TB_EXE)
	$(VVP) ./$<

$(POST_SYNTH_TB_EXE): $(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE) $(DUMPER_FILE)
	$(IVERILOG) $(IVFLAGS_SYN) \
		-DDUMP_FILE='"$(POST_SYNTH_DUMP)"' -DDUMP_SCOPE=$(POST_SYNTH_TB_MODULE) \
		-s $(POST_SYNTH_TB_MODULE) -s glbl -s $(DUMPER_MODULE) -o $(POST_SYNTH_TB_EXE) \
		$(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(GLBL_FILE) $(DUMPER_FILE)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(DUMP_FILE) $(DUMP_FILE).hier $(TESTBENCH_MODULE)
	rm -rf $(POST_SYNTH_DUMP) $(POST_SYNTH_DUMP).hier $(POST_SYNTH_TB_EXE)
