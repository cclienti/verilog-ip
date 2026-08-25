# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_packet_fifo
TOP_FILE          ?= ../src/axi_stream_packet_fifo.sv
TOP_DEPS          ?= ../../dpmemrf ../../sclkfifolut

TESTBENCH_MODULE  ?= axi_stream_packet_fifo_tb
TESTBENCH_FILE    ?= ../src/axi_stream_packet_fifo_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= axi_stream_packet_fifo.xdc

VIVADO_PROJECT_OOC ?= 1

include ../../../Makefiles/common.mk
include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/vivado.mk
