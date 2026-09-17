# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_udp_socket
TOP_FILE          ?= ../src/axi_stream_udp_socket.sv
TOP_DEPS          ?= ../../../../lib/axi_stream_packet_fifo

TESTBENCH_MODULE  ?= axi_stream_udp_socket_tb
TESTBENCH_FILE    ?= ../src/axi_stream_udp_socket_tb.sv
TESTBENCH_DEPS    ?= ../../udp_model

VIVADO_BOARDFILE  ?= axi_stream_udp_socket.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
