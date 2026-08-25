# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_eth_fcs_gen
TOP_FILE          ?= ../src/axi_stream_eth_fcs_gen.sv
TOP_DEPS          ?= ../../../../lib/crc32

TESTBENCH_MODULE  ?= axi_stream_eth_fcs_gen_tb
TESTBENCH_FILE    ?= ../src/axi_stream_eth_fcs_gen_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= axi_stream_eth_fcs_gen.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
