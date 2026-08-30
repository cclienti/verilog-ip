# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= zedboard_eth_endpoint
TOP_FILE          ?= ../src/zedboard_eth_endpoint.sv
TOP_DEPS          ?= ../../../../network/ethernet/rmii_eth_endpoint

TESTBENCH_MODULE  ?= zedboard_eth_endpoint_tb
TESTBENCH_FILE    ?= ../src/zedboard_eth_endpoint_tb.sv
TESTBENCH_DEPS    ?=

# A board project, not an OOC block: full pin constraints, and
# impl.vivado writes zedboard_eth_endpoint.bit next to its reports.
# The repo-wide VIVADO_SYNTH_OPTIONS default carries -no_iobuf for the
# OOC module runs; a bitstream needs real IO buffers, so drop it here
VIVADO_BOARDFILE     ?= zedboard_eth_endpoint.xdc
VIVADO_PROJECT_OOC   ?= 0
VIVADO_BITSTREAM     ?= 1
VIVADO_PART          ?= xc7z020clg484-1
VIVADO_JTAG_DEVICE   ?= xc7z020_1
VIVADO_SYNTH_OPTIONS ?= -flatten_hierarchy full

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
