# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    = ../src/hynoc_ingress_tb.v
TESTBENCH_MODULE  = hynoc_ingress_tb

INCLUDE_DIRS	  = ../../hynoc_ingress/src

VCD_FILE          = hynoc_ingress_tb.vcd

TOP_FILE          = ../src/hynoc_ingress.v
TOP_MODULE        = hynoc_ingress

TESTBENCH_DEPS    = ../../../../lib/report/src/report.v

TOP_DEPS          = ../src/hynoc_ingress_routing_ucast.v \
					../src/hynoc_ingress_routing_mcast.v \
					../../../../lib/sclkfifolut/src/sclkfifolut.v \
					../../../../lib/dclkfifolut/src/dclkfifolut.v \
					../../../../lib/bin2gray/src/bin2gray.v \
					../../../../lib/gray2bin/src/gray2bin.v



include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/modelsim.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/vtov.mk
include ../../../../Makefiles/common.mk
