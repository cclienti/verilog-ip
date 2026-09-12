# Copyright (C) 2013-2019 Christophe Clienti - All Rights Reserved

# A package, not a synthesizable block: no constraints, no Vivado, no
# waveforms. The bench is the package's self-check.
TOP_MODULE        ?= tcp_model_pkg
TOP_FILE          ?= ../src/tcp_model_pkg.sv
TOP_DEPS          ?=

TESTBENCH_MODULE  ?= tcp_model_pkg_tb
TESTBENCH_FILE    ?= ../src/tcp_model_pkg_tb.sv
TESTBENCH_DEPS    ?=

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
include ../../../../Makefiles/verilator.mk
