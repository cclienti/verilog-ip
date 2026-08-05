# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_router_5p
TOP_FILE          ?= ../src/hynoc_router_5p.v
TOP_DEPS          ?= ../../hynoc_router_base

# The bench every per-bench target acts on -- sim, trace, check alike.
# Override on the command line to work on another:
#
#   make check.iverilog TESTBENCH_MODULE=hynoc_router_5p_tb2
TESTBENCH_MODULE  ?= hynoc_router_5p_tb5
TESTBENCH_FILE    ?= ../src/$(TESTBENCH_MODULE).v
TESTBENCH_DEPS    ?= ../../hynoc_stream_writer \
			../../hynoc_stream_reader \
			../../hynoc_local_interface \
			../../../../lib/dclkfifolut
TESTBENCH_PARAMS  ?=
# TESTBENCH_PARAMS  ?= SINGLE_CLOCK_ROUTER=1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
include ../../../../Makefiles/quartus.mk
include ../../../../Makefiles/veriparse.mk
include ../../../../Makefiles/modelsim.mk

#----------------------------------------------------------------------
# Five testbenches live here, which the generic makefiles deliberately do
# not model: covering them all is this file's job.
#
# check.iverilog gains the four unselected benches as prerequisites, each
# checked by recursing with its name -- TESTBENCH_FILE and the source
# list derive from TESTBENCH_MODULE, so a sibling has to be built by a
# make that was told which one it is. The recursed make sees the name on
# its command line and the guard below then adds no prerequisites, which
# both stops the recursion and makes the override in the comment above
# check just that one bench. One target per bench rather than a shell
# loop so -j spreads them and -k reports every failure.
#
# tb4 runs 854 s and tb5 423 s: the full check is about 21 minutes.
#----------------------------------------------------------------------
OTHER_TESTBENCHES = hynoc_router_5p_tb  hynoc_router_5p_tb2 \
                    hynoc_router_5p_tb3 hynoc_router_5p_tb4

ifeq ($(origin TESTBENCH_MODULE),file)
check.iverilog: $(addprefix check@,$(OTHER_TESTBENCHES))
endif

# Not .PHONY: make excludes phony targets from implicit rule search, and
# the pattern would silently stop matching.
check@%:
	@$(MAKE) --no-print-directory check.iverilog TESTBENCH_MODULE=$*

# The generic clean only knows the selected bench; the other executables
# and dumps are this file's to sweep.
clean::
	rm -rf $(foreach tb,$(OTHER_TESTBENCHES),$(tb) $(tb).$(IVERILOG_DUMPER) $(tb).$(IVERILOG_DUMPER).hier)
