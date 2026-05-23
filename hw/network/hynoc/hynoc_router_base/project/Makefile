# Logic Unit Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= hynoc_router_base
TOP_FILE          ?= ../src/hynoc_router_base.v
TOP_DEPS          ?= ../../hynoc_ingress ../../hynoc_egress
VIVADO_BOARDFILE  := $(abspath vivado.xdc)
VIVADO_PART       := xc7z020clg484-1  #xc7k160tfbg484-2

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/vivado.mk
include ../../../../Makefiles/quartus.mk
include ../../../../Makefiles/veriparse.mk
