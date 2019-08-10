# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_FILE    =
TESTBENCH_MODULE  =

VCD_FILE          =

TOP_FILE          = ../src/hynoc_router_base.v
TOP_MODULE        = hynoc_router_base

TESTBENCH_DEPS    =

TOP_DEPS          = ../../hynoc_ingress/src/hynoc_ingress.v \
			../../hynoc_egress/src/hynoc_egress.v \
			../../hynoc_prra/src/hynoc_prra.v \
			../../../../lib/prra_lut/src/prra_lut.v \
			../../../../lib/dclkfifolut/src/dclkfifolut.v \
			../../../../lib/bin2gray/src/bin2gray.v \
			../../../../lib/gray2bin/src/gray2bin.v


include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/xilinx.mk
include ../../../../Makefiles/common.mk
