# Component Library
# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/smalldiv_tb.v
TESTBENCH_MODULE  = smalldiv_tb

VCD_FILE          = smalldiv_tb.vcd

TOP_FILE         ?= ../src/smalldiv.v
TOP_MODULE        = smalldiv

TESTBENCH_DEPS    =

TOP_DEPS          = ../src/smalldiv_lut.v


include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/xilinx.mk
include ../../../Makefiles/veriparse.mk
include ../../../Makefiles/common.mk
