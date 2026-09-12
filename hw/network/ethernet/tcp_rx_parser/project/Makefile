# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= tcp_rx_parser
TOP_FILE          ?= ../src/tcp_rx_parser.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= tcp_rx_parser_tb
TESTBENCH_FILE    ?= ../src/tcp_rx_parser_tb.sv
TESTBENCH_DEPS    ?= ../../tcp_model

VIVADO_BOARDFILE  ?= tcp_rx_parser.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
