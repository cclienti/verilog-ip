# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= tcp_connection_fsm
TOP_FILE          ?= ../src/tcp_connection_fsm.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= tcp_connection_fsm_tb
TESTBENCH_FILE    ?= ../src/tcp_connection_fsm_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= tcp_connection_fsm.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
