# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG           ?= iverilog
IVFLAGS            += -Wall -Wno-sensitivity-entire-array -g2005
IVFLAGS            += $(foreach DIR,$(ALL_TOP_FILES),-I $(dir $(DIR)))
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
	! vvp ./$< -lxt2 | grep Error

$(VCD_FILE): $(TESTBENCH_MODULE)
	vvp ./$< -lxt2

$(TESTBENCH_MODULE): $(ALL_SOURCE_FILES)
	$(IVERILOG) $(IVFLAGS)  -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(ALL_SOURCE_FILES)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(VCD_FILE) $(TESTBENCH_MODULE)
