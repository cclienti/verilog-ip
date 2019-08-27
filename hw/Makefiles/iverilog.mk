# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG          = iverilog
GTKWAVE           = gtkwave
IVFLAGS          += -Wall -Wno-sensitivity-entire-array -g2005 $(foreach dir,$(INCLUDE_DIRS),-I$(dir))

VCD_SAV           = $(subst .vcd,.sav,$(VCD_FILE))

help::
	@echo "trace - simulate design with iverilog and show the vcd with gtkwave"
	@echo "vcd - simulate the design with iverilog"

trace: vcd $(WAVEDISP_GTKWAVE_TCL)
	gtkwave -S $(WAVEDISP_GTKWAVE_TCL) $(VCD_FILE)

vcd: $(VCD_FILE)

$(VCD_FILE): $(TESTBENCH_MODULE)
	! vvp ./$< -lxt2 | grep Error

$(TESTBENCH_MODULE): $(TESTBENCH_FILE) $(TOP_FILE) $(TOP_DEPS) $(TESTBENCH_DEPS)
	$(IVERILOG) $(IVFLAGS)  -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(sort $(TOP_DEPS) $(TESTBENCH_DEPS) $(TOP_FILE) $(TESTBENCH_FILE))

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(VCD_FILE) $(TESTBENCH_MODULE)
