# Hynoc stream reader Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

TESTBENCH_MODULE  = hynoc_stream_reader_tb

TESTBENCH_FILE    = ../src/hynoc_stream_reader_tb.v

VCD_FILE          = hynoc_stream_reader_tb.vcd

TOP_FILE          = ../src/hynoc_stream_reader.v
TOP_MODULE        = hynoc_stream_reader

TESTBENCH_DEPS    = ../../hynoc_stream_writer/src/hynoc_stream_writer.v \
			../../../../lib/dclkfifolut/src/dclkfifolut.v \
			../../../../lib/gray2bin/src/gray2bin.v \
			../../../../lib/bin2gray/src/bin2gray.v

TOP_DEPS          =

include ../../../../Makefiles/common.mk
include ../../../../Makefiles/iverilog.mk
