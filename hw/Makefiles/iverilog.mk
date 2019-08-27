# Generic Icarus Verilog Makefile
# Copyright (C) 2013-2016 Christophe Clienti - All Rights Reserved

IVERILOG          = iverilog
GTKWAVE           = gtkwave
IVFLAGS          += -Wall -Wno-sensitivity-entire-array -g2005 $(foreach dir,$(INCLUDE_DIRS),-I$(dir))

VCD_SAV           = $(subst .vcd,.sav,$(VCD_FILE))
GTKWAVE_WAVE_FILE = $(TESTBENCH_MODULE).wave.py
GTKWAVE_TCL       = $(TESTBENCH_MODULE).gtkwave.tcl

help::
	@echo "trace - simulate design with iverilog and show the vcd with gtkwave"
	@echo "vcd - simulate the design with iverilog"

trace: vcd wavedisp
	gtkwave -T $(GTKWAVE_TCL) $(VCD_FILE)

vcd: $(VCD_FILE)

wavedisp: $(GTKWAVE_TCL)

$(VCD_FILE): $(TESTBENCH_MODULE)
	! vvp ./$< -lxt2 | grep Error

$(TESTBENCH_MODULE): $(TESTBENCH_FILE) $(TOP_FILE) $(TOP_DEPS) $(TESTBENCH_DEPS)
	$(IVERILOG) $(IVFLAGS)  -s $(TESTBENCH_MODULE) -o $(TESTBENCH_MODULE) \
		$(sort $(TOP_DEPS) $(TESTBENCH_DEPS) $(TOP_FILE) $(TESTBENCH_FILE))

$(GTKWAVE_TCL): $(GTKWAVE_WAVE_FILE)
	wavedisp -t gtkwave -o $@ $^ || rm -f $(GTKWAVE_TCL)

clean:: iverilog_clean

iverilog_clean:
	rm -rf $(VCD_FILE) $(TESTBENCH_MODULE) $(GTKWAVE_TCL)
