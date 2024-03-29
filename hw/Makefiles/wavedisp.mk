WAVEDISP_FILE            = $(TESTBENCH_MODULE).wave.py
WAVEDISP_GTKWAVE_TCL     = $(TESTBENCH_MODULE).gtkwave.tcl
WAVEDISP_MODELSIM_TCL    = $(TESTBENCH_MODULE).modelsim.tcl
WAVEDISP_RIVIERAPRO_TCL  = $(TESTBENCH_MODULE).rivierapro.tcl
WAVEDISP_DOT_FILE        = $(TESTBENCH_MODULE).dot

ifeq ($(WAVEDISP_GEN_ARGS),)
WAVEDISP_KWARGS :=
else
WAVEDISP_KWARGS := -a '$(WAVEDISP_GEN_ARGS)'
endif


.PHONY: $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) $(WAVEDISP_RIVIERAPRO_TCL)


help::
	@echo "wavedisp - generate all wavedisp files"
	@echo "wavedisp_dot - generate and display the dot diagram of the AST"

wavedisp: $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) $(WAVEDISP_RIVIERAPRO_TCL)

wavedisp_dot: $(WAVEDISP_DOT_FILE)
	xdot $^

$(WAVEDISP_GTKWAVE_TCL): $(WAVEDISP_FILE)
	wavedisp -t gtkwave -o $@ $^ $(WAVEDISP_KWARGS)

$(WAVEDISP_MODELSIM_TCL): $(WAVEDISP_FILE)
	wavedisp -t modelsim -o $@ $^ $(WAVEDISP_KWARGS)

$(WAVEDISP_RIVIERAPRO_TCL): $(WAVEDISP_FILE)
	wavedisp -t rivierapro -o $@ $^ $(WAVEDISP_KWARGS)

$(WAVEDISP_DOT_FILE): $(WAVEDISP_FILE)
	wavedisp -t dot -o $@ $^ $(WAVEDISP_KWARGS)

clean:: wavedisp_clean

wavedisp_clean:
	rm -rf $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) \
		$(WAVEDISP_RIVIERAPRO_TCL) $(WAVEDISP_DOT_FILE) \
		__pycache__
