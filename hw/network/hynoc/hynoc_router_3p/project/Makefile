# Logic Unit Makefile
# Copyright (C) 2013-2020 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_router_3p
TOP_FILE          ?= ../src/hynoc_router_3p.v
TOP_DEPS          ?= ../../hynoc_router_base

TESTBENCH_MODULE  ?= hynoc_router_3p_tb
TESTBENCH_FILE    ?= ../src/$(TESTBENCH_MODULE).v ../src/local_reader.v
TESTBENCH_DEPS    ?= ../../hynoc_local_interface
TESTBENCH_PARAMS  ?=


include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/quartus.mk
include ../../../../Makefiles/veriparse.mk
include ../../../../Makefiles/modelsim.mk
