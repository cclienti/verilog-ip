# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= axi_stream_eth_fcs_check
TOP_FILE          ?= ../src/axi_stream_eth_fcs_check.sv
TOP_DEPS          ?= ../../../../lib/crc32

TESTBENCH_MODULE  ?= axi_stream_eth_fcs_check_tb
TESTBENCH_FILE    ?= ../src/axi_stream_eth_fcs_check_tb.sv
TESTBENCH_DEPS    ?= ../../axi_stream_eth_fcs_gen \
			../../rmii_mac_tx \
			../../rmii_mac_rx \
			../../../../lib/axi_stream_downsizer \
			../../../../lib/axi_stream_upsizer \
			../../../../lib/axi_stream_packet_fifo


include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
