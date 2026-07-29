# Component Library
# Copyright (C) 2026 Christophe Clienti - All Rights Reserved

TOP_MODULE        ?= parmem17_16
TOP_FILE          ?= ../src/parmem17_16.sv
TOP_DEPS          ?= ../../../dpmemrf

TESTBENCH_MODULE  ?= parmem17_16_tb
TESTBENCH_FILE    ?= ../src/parmem17_16_tb.sv
TESTBENCH_DEPS    ?=

# Component-local timing constraints (clka/clkb, async groups, I/O delays)
# instead of the default board pin file -- resolved relative to this dir.
VIVADO_BOARDFILE   ?= parmem17_16.xdc

# Module-level fmax study: synthesize out of context (no IOBUFs).
VIVADO_PROJECT_OOC ?= 1

# Reference figures (M17L16 sweep, hw/lib/parmem/doc/RESULTS.md):
#   make vivado-gen-post-impl VIVADO_SYNTH_OPTIONS="-flatten_hierarchy full \
#     -no_iobuf -generic OUTREGA=1 -generic OUTREGB=1 -generic ADRREG=1"


include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
include ../../../../Makefiles/modelsim.mk
include ../../../../Makefiles/quartus.mk
include ../../../../Makefiles/wavedisp.mk
include ../../../../Makefiles/vivado.mk
