# Component Library
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= shmemif
TOP_FILE          ?= ../src/shmemif.v
TOP_DEPS          ?= ../../prra_lut

TESTBENCH_MODULE  ?= shmemif_tb
TESTBENCH_FILE    ?= ../src/shmemif_tb.v
TESTBENCH_DEPS    ?= ../../dpmemrf

WAVEDISP_GEN_ARGS ?= {"nb_ports": 4}


include ../../../Makefiles/common.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/modelsim.mk
include ../../../Makefiles/quartus.mk
include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/vivado.mk
