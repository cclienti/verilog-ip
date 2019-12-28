# Component Library
# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE               ?= smalldiv
TOP_FILE                 ?= ../src/smalldiv.v
TOP_DEPS                 ?= ../src/smalldiv_lut.v

TESTBENCH_MODULE         ?= smalldiv_tb
TESTBENCH_FILE           ?= ../src/smalldiv_tb.v
TESTBENCH_DEPS           ?=

VCD_FILE                 ?= smalldiv_tb.vcd

QUARTUS_FAMILY           ?= "Cyclone IV E"
QUARTUS_PART             ?= EP4CE22F17C6

include ../../../Makefiles/common.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/xilinx.mk
include ../../../Makefiles/quartus.mk
include ../../../Makefiles/veriparse.mk
