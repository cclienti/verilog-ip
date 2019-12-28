# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/hynoc_egress_tb.v
TESTBENCH_MODULE  = hynoc_egress_tb

VCD_FILE          = hynoc_egress_tb.vcd

TOP_FILE          = ../src/hynoc_egress.v
TOP_MODULE        = hynoc_egress

TESTBENCH_DEPS    =

TOP_DEPS          = ../../hynoc_prra/src/hynoc_prra.v \
					../../../../lib/prra_lut/src/prra_lut.v



include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
