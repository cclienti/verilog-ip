# Wavedisp venv management
WAVEDISP_VENV_DIR        ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))/.venv
WAVEDISP_VENV_PYTHON      = $(WAVEDISP_VENV_DIR)/bin/python
WAVEDISP_VENV_PIP         = $(WAVEDISP_VENV_DIR)/bin/pip
WAVEDISP_BIN              = $(WAVEDISP_VENV_DIR)/bin/wavedisp

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
.PHONY: wavedisp wavedisp_dot wavedisp_venv


help::
	@echo "wavedisp        - generate all wavedisp files"
	@echo "wavedisp_dot    - generate and display the dot diagram of the AST"
	@echo "wavedisp_venv   - create the Python venv and install wavedisp"

# Create venv and install wavedisp from PyPI if not already installed
$(WAVEDISP_BIN):
	@echo "[wavedisp] Creating Python venv in $(WAVEDISP_VENV_DIR)..."
	python3 -m venv $(WAVEDISP_VENV_DIR)
	@echo "[wavedisp] Installing wavedisp from PyPI..."
	$(WAVEDISP_VENV_PIP) install --upgrade pip --quiet
	$(WAVEDISP_VENV_PIP) install wavedisp --quiet
	@echo "[wavedisp] wavedisp installed successfully."

wavedisp_venv: $(WAVEDISP_BIN)

wavedisp: $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) $(WAVEDISP_RIVIERAPRO_TCL)

wavedisp_dot: $(WAVEDISP_DOT_FILE)
	xdot $^

$(WAVEDISP_GTKWAVE_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t gtkwave -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_MODELSIM_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t modelsim -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_RIVIERAPRO_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t rivierapro -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_DOT_FILE): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t dot -o $@ $< $(WAVEDISP_KWARGS)

clean:: wavedisp_clean

wavedisp_clean:
	rm -rf $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) \
		$(WAVEDISP_RIVIERAPRO_TCL) $(WAVEDISP_DOT_FILE) \
		__pycache__
