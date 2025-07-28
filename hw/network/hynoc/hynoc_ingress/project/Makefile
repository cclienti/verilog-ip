# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_ingress
TOP_FILE          ?= ../src/hynoc_ingress.v
TOP_DEPS          ?= ../src/hynoc_ingress_routing_ucast.v \
			../src/hynoc_ingress_routing_mcast.v \
			../../../../lib/sclkfifolut \
			../../../../lib/dclkfifolut

TESTBENCH_MODULE  ?= hynoc_ingress_tb
TESTBENCH_FILE    ?= ../src/hynoc_ingress_tb.v
TESTBENCH_DEPS    ?= ../../../../lib/report/src/report.v


include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/modelsim.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
