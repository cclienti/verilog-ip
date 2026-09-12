# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= tcp_tx_frame
TOP_FILE          ?= ../src/tcp_tx_frame.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= tcp_tx_frame_tb
TESTBENCH_FILE    ?= ../src/tcp_tx_frame_tb.sv
TESTBENCH_DEPS    ?= ../../tcp_model

VIVADO_BOARDFILE  ?= tcp_tx_frame.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
