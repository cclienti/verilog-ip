# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_router_5p
TOP_FILE          ?= ../src/hynoc_router_5p.v
TOP_DEPS          ?= ../../hynoc_router_base

TESTBENCH_MODULE  ?= hynoc_router_5p_tb5
TESTBENCH_FILE    ?= ../src/hynoc_router_5p_tb5.v
TESTBENCH_DEPS    ?= ../../hynoc_stream_writer \
			../../hynoc_stream_reader \
			../../hynoc_local_interface \
			../../../../lib/dclkfifolut


include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/quartus.mk
include ../../../../Makefiles/veriparse.mk
include ../../../../Makefiles/modelsim.mk
