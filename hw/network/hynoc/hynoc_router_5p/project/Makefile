# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_MODULE := hynoc_router_5p_tb5

TESTBENCH_FILE    = ../src/$(TESTBENCH_MODULE).v

VCD_FILE          = $(TESTBENCH_MODULE).vcd

INCLUDE_DIRS	  = ../../hynoc_ingress/src

TOP_FILE          = ../src/hynoc_router_5p.v
TOP_MODULE        = hynoc_router_5p

POST_SYNTH_FILE   = xilinx/$(TOP_MODULE)/$(TOP_MODULE)_simsyn.v

TESTBENCH_DEPS    = ../../hynoc_stream_writer/src/hynoc_stream_writer.v \
					../../hynoc_stream_reader/src/hynoc_stream_reader.v \
					../../hynoc_local_interface/src/hynoc_local_interface.v \
					../../../../lib/dclkfifolut/src/dclkfifolut.v \
					../../../../lib/bin2gray/src/bin2gray.v \
					../../../../lib/gray2bin/src/gray2bin.v

TOP_DEPS          = ../../hynoc_router_base/src/hynoc_router_base.v \
					../../hynoc_ingress/src/hynoc_ingress_routing_ucast.v \
					../../hynoc_ingress/src/hynoc_ingress_routing_mcast.v \
					../../hynoc_ingress/src/hynoc_ingress.v \
					../../hynoc_egress/src/hynoc_egress.v \
					../../hynoc_prra/src/hynoc_prra.v \
					../../../../lib/prra_lut/src/prra_lut.v \
					../../../../lib/sclkfifolut/src/sclkfifolut.v \
					../../../../lib/dclkfifolut/src/dclkfifolut.v \
					../../../../lib/bin2gray/src/bin2gray.v \
					../../../../lib/gray2bin/src/gray2bin.v

include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/yosys.mk
include ../../../../Makefiles/modelsim.mk
include ../../../../Makefiles/vtov.mk
include ../../../../Makefiles/common.mk
