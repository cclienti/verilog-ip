# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= rmii_eth_endpoint
TOP_FILE          ?= ../src/rmii_eth_endpoint.sv
TOP_DEPS          ?= ../../rmii_mac_rx \
			../../rmii_mac_tx \
			../../axi_stream_eth_fcs_gen \
			../../axi_stream_eth_fcs_check \
			../../axi_stream_eth_parser \
			../../axi_stream_eth_arp \
			../../axi_stream_ipv4_parser \
			../../axi_stream_icmp_echo \
			../../../../lib/axi_stream_upsizer \
			../../../../lib/axi_stream_downsizer \
			../../../../lib/axi_stream_packet_fifo \
			../../../../lib/axi_stream_packet_demux \
			../../../../lib/axi_stream_packet_mux

TESTBENCH_MODULE  ?= rmii_eth_endpoint_tb
TESTBENCH_FILE    ?= ../src/rmii_eth_endpoint_tb.sv
TESTBENCH_DEPS    ?=

VIVADO_BOARDFILE  ?= rmii_eth_endpoint.xdc
VIVADO_PROJECT_OOC ?= 1

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
