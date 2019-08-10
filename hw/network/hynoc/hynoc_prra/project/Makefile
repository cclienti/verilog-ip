# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/hynoc_prra_tb.v
TESTBENCH_MODULE  = hynoc_prra_tb

VCD_FILE          = hynoc_prra_tb.vcd

TOP_FILE          = ../src/hynoc_prra.v
TOP_MODULE        = hynoc_prra

TESTBENCH_DEPS    =

TOP_DEPS          = ../../../../lib/prra_lut/src/prra_lut.v



include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/common.mk
