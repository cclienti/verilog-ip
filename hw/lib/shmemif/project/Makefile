# Component Library
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/shmemif_tb.v
TESTBENCH_MODULE  = shmemif_tb

VCD_FILE          = shmemif_tb.vcd

TOP_FILE          = ../src/shmemif.v
TOP_MODULE        = shmemif

TESTBENCH_DEPS    = ../../dpmemrf/src/dpmemrf.v

TOP_DEPS          = ../../prra_lut/src/prra_lut.v

WAVEDISP_GEN_ARGS = {"nb_ports": 4}

include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/modelsim.mk
include ../../../Makefiles/xilinx.mk
include ../../../Makefiles/yosys.mk
include ../../../Makefiles/common.mk
