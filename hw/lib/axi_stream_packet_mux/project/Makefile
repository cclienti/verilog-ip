# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_packet_mux
TOP_FILE          ?= ../src/axi_stream_packet_mux.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= axi_stream_packet_mux_tb
TESTBENCH_FILE    ?= ../src/axi_stream_packet_mux_tb.sv
TESTBENCH_DEPS    ?= ../../axi_stream_packet_demux

VIVADO_BOARDFILE  ?= axi_stream_packet_mux.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../Makefiles/common.mk
include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/vivado.mk
