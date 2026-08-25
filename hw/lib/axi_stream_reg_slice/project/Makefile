# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_reg_slice
TOP_FILE          ?= ../src/axi_stream_reg_slice.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= axi_stream_reg_slice_tb
TESTBENCH_FILE    ?= ../src/axi_stream_reg_slice_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= axi_stream_reg_slice.xdc

VIVADO_PROJECT_OOC ?= 1

include ../../../Makefiles/common.mk
include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/vivado.mk
