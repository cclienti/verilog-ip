# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_packet_demux
TOP_FILE          ?= ../src/axi_stream_packet_demux.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= axi_stream_packet_demux_tb
TESTBENCH_FILE    ?= ../src/axi_stream_packet_demux_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= axi_stream_packet_demux.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../Makefiles/common.mk
include ../../../Makefiles/wavedisp.mk
include ../../../Makefiles/iverilog.mk
include ../../../Makefiles/verilator.mk
include ../../../Makefiles/vivado.mk
