# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG           ?= iverilog
VVP                ?= vvp
IVSTD              ?= -g2012
IVFLAGS            += -Wall -Wno-sensitivity-entire-array $(IVSTD)
IVFLAGS            += $(foreach DIR,$(ALL_TOP_FILES),-I$(dir $(DIR)))
IVFLAGS            += $(foreach PARAM,$(TESTBENCH_PARAMS),-P$(TESTBENCH_MODULE).$(PARAM))
GTKWAVE            ?= gtkwave
VCD_FILE           ?= $(TESTBENCH_MODULE).vcd

help::
	@echo "trace - simulate design with iverilog and show the vcd with gtkwave"
	@echo "vcd - simulate the design with iverilog"

trace: vcd $(WAVEDISP_GTKWAVE_TCL)
	gtkwave -S $(WAVEDISP_GTKWAVE_TCL) $(VCD_FILE)

vcd: $(VCD_FILE)

sim: $(VCD_FILE)

check: $(TESTBENCH_MODULE)
	! $(VVP) ./$< -lxt2 | grep Error

$(VCD_FILE): $(TESTBENCH_MODULE)
	$(VVP) ./$< -lxt2

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES)
	$(IVERILOG) $(IVFLAGS) -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(VCD_FILE) $(TESTBENCH_MODULE)
