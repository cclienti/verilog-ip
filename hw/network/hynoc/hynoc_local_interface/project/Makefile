# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/hynoc_local_interface_tb.v
TESTBENCH_MODULE  = hynoc_local_interface_tb

VCD_FILE          = hynoc_local_interface_tb.vcd

TOP_FILE          = ../src/hynoc_local_interface.v
TOP_MODULE        = hynoc_local_interface

TESTBENCH_DEPS    =

TOP_DEPS          = ../../../../lib/sclkfifolut/src/sclkfifolut.v \
					../../../../lib/dclkfifolut/src/dclkfifolut.v \
					../../../../lib/bin2gray/src/bin2gray.v \
					../../../../lib/gray2bin/src/gray2bin.v



include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/common.mk
