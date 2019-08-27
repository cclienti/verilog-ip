# Component Library
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/dclkfifolut_tb.v
TESTBENCH_MODULE  = dclkfifolut_tb

VCD_FILE          = dclkfifolut_tb.vcd

TOP_FILE          = ../src/dclkfifolut.v
TOP_MODULE        = dclkfifolut

TESTBENCH_DEPS    =

TOP_DEPS          = ../../gray2bin/src/gray2bin.v \
			../../bin2gray/src/bin2gray.v


include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/modelsim.mk
include ../../../Makefiles/xilinx.mk
include ../../../Makefiles/yosys.mk
include ../../../Makefiles/common.mk
