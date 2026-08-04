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
# GLBL_FILE: Xilinx glbl module (provides glbl.GSR used by FDRE/RAM primitives).
#            Copied from the Vivado installation into vivado-post-syn/ by vivado-gen-post-syn.
#            Override in the project Makefile if needed.
POST_SYNTH_FILE       ?= vivado-post-syn/$(TOP_MODULE)_syn.v

# The RTL testbench is reused as is. What separates the two runs is small
# enough for the testbench to bracket with `ifdef POST_SYNTH, which
# IVFLAGS_SYN defines: the netlist takes no parameter override, the Xilinx
# flip-flops stay held until glbl.GSR falls, and any probe reaching into a
# hierarchy that `-flatten_hierarchy full` dissolved no longer resolves.
# Delays need no rescaling -- each file keeps its own `timescale, so the
# netlist imposes its 1 ps precision without the testbench changing units.
#
# A project preferring a separate testbench drops <testbench>_postsyn.sv
# beside the RTL one and it is picked up instead. wildcard is safe here,
# unlike inside a recipe: this is a source file, never a build product.
POST_SYNTH_TB_FILE    ?= $(or $(wildcard $(dir $(TESTBENCH_FILE))$(TESTBENCH_MODULE)_postsyn.sv),$(TESTBENCH_FILE))
POST_SYNTH_TB_MODULE  ?= $(basename $(notdir $(POST_SYNTH_TB_FILE)))

# The testbench's own support modules -- memory models, checkers -- are
# the testbench side of the source list. Only the design side is replaced
# by the netlist: shmemif's testbench instantiates dpmemrf, which the
# netlist neither contains nor should.
#
# Both testbenches are excluded, not just the one being built: where a
# dedicated _postsyn.sv exists, the RTL testbench is still in the source
# list, and compiling the two together instantiates the DUT twice.
POST_SYNTH_TB_DEPS    ?= $(filter-out $(ALL_TOP_FILES) $(realpath $(TESTBENCH_FILE) $(POST_SYNTH_TB_FILE)),$(ALL_SOURCE_FILES))

# Named after the target rather than after the module: sharing the RTL
# testbench means sharing its module name too, and the post-synthesis run
# must not overwrite the RTL executable and dump.
POST_SYNTH_TB_EXE     ?= $(TESTBENCH_MODULE)_postsyn
POST_SYNTH_DUMP       ?= $(POST_SYNTH_TB_EXE).$(IVERILOG_DUMPER)
GLBL_FILE             ?= vivado-post-syn/glbl.v
IVFLAGS_SYN           := -Wno-sensitivity-entire-array $(IVSTD) -DPOST_SYNTH
IVFLAGS_SYN           += $(foreach DIR,$(ALL_TOP_FILES),-I$(dir $(DIR)))
IVFLAGS_SYN           += -I$(dir $(POST_SYNTH_TB_FILE))

# gtkwave writes back into the save file it was given: File > Write Save
# File lands in whatever -a named. Binding that to the generated file
# would mean an arrangement built by hand in the gui is overwritten by the
# next trace, and .gitignore excludes it, so it was never recoverable.
#
# A hand-written <testbench>.sav therefore wins when one exists. It is
# yours, it is tracked -- thirteen of them live in this repository -- and
# nothing here regenerates it, so gtkwave saving into it is what you want.
# Write one from the gui under that name to keep a layout for good.
GTKWAVE_USER_SAV       = $(wildcard $(TESTBENCH_MODULE).sav)

# Surfer replays a command file after loading the dump. Same guard: no
# save script, no option.
SURFER_COMMANDS        = $(if $(WAVEDISP_SURFER_FILE),--command-file $(WAVEDISP_SURFER_FILE))

# Where the post-synthesis run shares the RTL testbench, it shares its
# top and its scope names, so the script wavedisp already generates
# applies unchanged. The signals it lists inside the DUT are the ones
# synthesis flattened away, and a viewer skips what it cannot resolve.
#
# A project with its own _postsyn testbench has a different top, and
# wavedisp only generates for $(TESTBENCH_MODULE), so its script is
# looked up under that name and has to be written by hand. wildcard is
# right there precisely because nothing generates the file -- it would be
# wrong above, where the recipe creates the very file it tests for, and
# the whole recipe is expanded before its first line runs.
ifeq ($(POST_SYNTH_TB_MODULE),$(TESTBENCH_MODULE))
POST_SYNTH_GTKWAVE_TCL  = $(WAVEDISP_GTKWAVE_TCL)
POST_SYNTH_SURFER_FILE  = $(WAVEDISP_SURFER_FILE)
else
POST_SYNTH_GTKWAVE_TCL ?= $(wildcard $(POST_SYNTH_TB_MODULE).gtkwave.tcl)
POST_SYNTH_SURFER_FILE ?= $(wildcard $(POST_SYNTH_TB_MODULE).sucl)
endif

# Still the tcl script here, where the RTL run has moved to gtkwave's own
# save format: a save file records the dump it was written from, so this
# path needs one of its own, generated with -D $(POST_SYNTH_DUMP). A tcl
# script names no dump and works for both.
POST_SYNTH_GTKWAVE_SCRIPT  = $(if $(POST_SYNTH_GTKWAVE_TCL),-S $(POST_SYNTH_GTKWAVE_TCL))
POST_SYNTH_SURFER_COMMANDS = $(if $(POST_SYNTH_SURFER_FILE),--command-file $(POST_SYNTH_SURFER_FILE))

.PHONY: sim.iverilog check.iverilog check-one.iverilog trace.gtkwave trace.surfer
.PHONY: sim-post-syn.iverilog trace-post-syn.gtkwave trace-post-syn.surfer
.PHONY: clean.iverilog

HELP_ENTRIES += 'sim.iverilog|simulate the design'
HELP_ENTRIES += 'check.iverilog|run every declared testbench without dumping, fail on any error'
HELP_ENTRIES += 'trace.gtkwave|simulate, then show the waveform with gtkwave'
HELP_ENTRIES += 'trace.surfer|simulate, then show the waveform with surfer'
HELP_ENTRIES += 'sim-post-syn.iverilog|simulate the post-synthesis netlist'
HELP_ENTRIES += 'trace-post-syn.gtkwave|simulate the netlist, then show the waveform with gtkwave'
HELP_ENTRIES += 'trace-post-syn.surfer|simulate the netlist, then show the waveform with surfer'

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
#
# The viewers are named after themselves rather than after the simulator
# that fed them: which one opens is the only thing that differs between
# these two, and hiding that behind a single `trace` was how the second
# viewer ended up as `trace-surfer`, an odd one out.
# The whole choice is made in one shell block because it depends on what
# the generation actually did, and a recipe is expanded before its first
# line runs -- a variable could not see the outcome.
#
# A failed generation must not cost you the viewer. wavedisp exits 1 when
# a declared signal is missing from the dump, which is exactly what
# happens after a port rename -- the moment you most need to look at the
# waveform. So the check reports, and the run falls back to the tcl
# script, which names no signals against the dump and always loads.
trace.gtkwave: sim.iverilog
	@view=""; \
	if [ -n "$(GTKWAVE_USER_SAV)" ]; then \
	  view="-a $(GTKWAVE_USER_SAV)"; \
	elif [ -n "$(WAVEDISP_GTKWAVE_SAV)" ]; then \
	  if $(MAKE) --no-print-directory $(WAVEDISP_GTKWAVE_SAV); then \
	    view="-a $(WAVEDISP_GTKWAVE_SAV)"; \
	  else \
	    echo "$(WAVEDISP_FILE): does not match the dump, opening with the tcl script instead"; \
	    $(MAKE) --no-print-directory $(WAVEDISP_GTKWAVE_TCL) && view="-S $(WAVEDISP_GTKWAVE_TCL)"; \
	  fi; \
	fi; \
	$(GTKWAVE) $$view $(DUMP_FILE)

# The dump is handed to wavedisp here and not in waves.wavedisp: the
# simulation has just run, so checking the declared signals against it is
# free, while the generation target must stay runnable without one.
#
# On a mismatch the check reports and the file is regenerated without it,
# rather than the whole target failing. wavedisp exits 1 when a declared
# signal is missing, which is what a port rename produces -- refusing to
# open the viewer there would withhold the waveform exactly when it is
# needed to understand the rename.
trace.surfer: sim.iverilog
	$(if $(WAVEDISP_SURFER_FILE),$(MAKE) $(WAVEDISP_SURFER_FILE) WAVEDISP_DUMP=$(DUMP_FILE) \
	    || $(MAKE) $(WAVEDISP_SURFER_FILE))
	$(SURFER) $(DUMP_FILE) $(SURFER_COMMANDS)

sim.iverilog: $(DUMP_FILE)

# check covers every testbench the project declares, not just the one
# sim and trace act on: hynoc_router_5p ships five and only the selected
# one was ever run, leaving three that pass in seconds permanently
# outside verification.
#
# One make target per testbench rather than a shell loop, because make
# parallelises targets, not recipes: a loop is a single job whatever -j
# says. With a target each, `make check.iverilog -j5` spreads them, `-k`
# reports every failure instead of stopping at the first, and
# `--output-sync=target` keeps the report readable. Do not force -j from
# here; that fights the caller's jobserver.
#
# Recursing is what makes each run correct, not just convenient:
# TESTBENCH_FILE and the source list derive from TESTBENCH_MODULE, so a
# sibling testbench has to be built by a make that was told its name.
TESTBENCH_MODULES ?= $(TESTBENCH_MODULE)

check.iverilog: $(addprefix check@,$(TESTBENCH_MODULES))

# Deliberately not .PHONY: make excludes phony targets from implicit rule
# search, so declaring these would stop the pattern rule from matching and
# `check` would silently do nothing.
check@%:
	@$(MAKE) --no-print-directory check-one.iverilog TESTBENCH_MODULE=$*

# The dump is written and never read here, so suppress it entirely: it
# makes the long testbenches noticeably faster.
#
# Failures are reported as "Error", "error", "FAIL:" or "FAIL [", so the
# pattern has to cover more than the capital-E form -- grep Error alone
# let "FAIL: 3 error(s) found" through and reported success. No passing
# testbench prints either word.
check-one.iverilog: $(TESTBENCH_MODULE)
	@out=$$(IVERILOG_DUMPER=none $(VVP) ./$< 2>&1); status=$$?; \
	echo "$$out"; \
	if [ $$status -ne 0 ] || echo "$$out" | grep -qiE 'error|fail'; then \
	  echo "$(TESTBENCH_MODULE): FAILED"; exit 1; fi

$(DUMP_FILE): $(TESTBENCH_MODULE)
	$(VVP) ./$<

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES) $(DUMPER_FILE)
	$(IVERILOG) $(IVFLAGS) \
		-DDUMP_FILE='"$(DUMP_FILE)"' -DDUMP_SCOPE=$(TESTBENCH_MODULE) \
		-s $(TESTBENCH_MODULE) -s $(DUMPER_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES) $(DUMPER_FILE)

# Post-synthesis targets
sim-post-syn.iverilog: $(POST_SYNTH_DUMP)

# The save script is regenerated only when it is the one wavedisp owns.
# A hand-written _postsyn script has no rule, and asking make to build it
# would just print that it is up to date.
trace-post-syn.gtkwave: $(POST_SYNTH_DUMP)
	$(if $(filter $(WAVEDISP_GTKWAVE_TCL),$(POST_SYNTH_GTKWAVE_TCL)),$(MAKE) $(POST_SYNTH_GTKWAVE_TCL))
	$(GTKWAVE) $(POST_SYNTH_GTKWAVE_SCRIPT) $(POST_SYNTH_DUMP)

trace-post-syn.surfer: $(POST_SYNTH_DUMP)
	$(if $(filter $(WAVEDISP_SURFER_FILE),$(POST_SYNTH_SURFER_FILE)),$(MAKE) $(POST_SYNTH_SURFER_FILE))
	$(SURFER) $(POST_SYNTH_DUMP) $(POST_SYNTH_SURFER_COMMANDS)

$(POST_SYNTH_DUMP): $(POST_SYNTH_TB_EXE)
	$(VVP) ./$<

$(POST_SYNTH_TB_EXE): $(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(POST_SYNTH_TB_DEPS) $(GLBL_FILE) $(DUMPER_FILE)
	$(IVERILOG) $(IVFLAGS_SYN) \
		-DDUMP_FILE='"$(POST_SYNTH_DUMP)"' -DDUMP_SCOPE=$(POST_SYNTH_TB_MODULE) \
		-s $(POST_SYNTH_TB_MODULE) -s glbl -s $(DUMPER_MODULE) -o $(POST_SYNTH_TB_EXE) \
		$(POST_SYNTH_FILE) $(POST_SYNTH_TB_FILE) $(POST_SYNTH_TB_DEPS) $(GLBL_FILE) $(DUMPER_FILE)

clean:: clean.iverilog

# Every declared testbench, not just the selected one: a project with
# several leaves the others' executables and dumps behind on every build,
# and they were invisible to both clean and .gitignore.
clean.iverilog:
	rm -rf $(DUMP_FILE) $(DUMP_FILE).hier $(TESTBENCH_MODULE)
	rm -rf $(foreach tb,$(TESTBENCH_MODULES),$(tb) $(tb).$(IVERILOG_DUMPER) $(tb).$(IVERILOG_DUMPER).hier)
	rm -rf $(POST_SYNTH_DUMP) $(POST_SYNTH_DUMP).hier $(POST_SYNTH_TB_EXE)
