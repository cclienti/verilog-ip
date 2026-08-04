# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_router_5p
TOP_FILE          ?= ../src/hynoc_router_5p.v
TOP_DEPS          ?= ../../hynoc_router_base

# The one sim and trace act on; override on the command line to look at
# another. check runs the whole list below, and narrowing it takes
# TESTBENCH_MODULES, not TESTBENCH_MODULE -- the list is set here, so
# overriding the singular leaves it untouched and all five still run:
#
#   make check.iverilog TESTBENCH_MODULES=hynoc_router_5p_tb2
#
# tb4 and tb5 take 854 s and 423 s, so the full check is about 21 minutes.
TESTBENCH_MODULE  ?= hynoc_router_5p_tb5
TESTBENCH_MODULES ?= hynoc_router_5p_tb  hynoc_router_5p_tb2 \
                     hynoc_router_5p_tb3 hynoc_router_5p_tb4 \
                     hynoc_router_5p_tb5
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
