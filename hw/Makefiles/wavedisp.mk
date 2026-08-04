# Wavedisp venv management
#
# An already-activated venv wins: if VIRTUAL_ENV is set, wavedisp is
# installed there rather than in a second, private one. That keeps an
# editable checkout (pip install -e) visible to the build instead of
# being shadowed by a PyPI copy.
ifdef VIRTUAL_ENV
WAVEDISP_VENV_DIR        ?= $(VIRTUAL_ENV)
else
WAVEDISP_VENV_DIR        ?= $(realpath $(dir $(lastword $(MAKEFILE_LIST))))/.venv
endif
WAVEDISP_VENV_PYTHON      = $(WAVEDISP_VENV_DIR)/bin/python
WAVEDISP_VENV_PIP         = $(WAVEDISP_VENV_DIR)/bin/pip
WAVEDISP_BIN              = $(WAVEDISP_VENV_DIR)/bin/wavedisp

WAVEDISP_FILE            = $(TESTBENCH_MODULE).wave.py
WAVEDISP_GTKWAVE_TCL     = $(TESTBENCH_MODULE).gtkwave.tcl
# gtkwave's own save format, which it loads with -a. Named like every
# other generated file and NOT <testbench>.sav: thirteen save files under
# that exact name are tracked in this repository, written by hand, and
# generating over them would overwrite them and clean would delete them.
WAVEDISP_GTKWAVE_SAV     = $(TESTBENCH_MODULE).gtkwave.sav
WAVEDISP_MODELSIM_TCL    = $(TESTBENCH_MODULE).modelsim.tcl
WAVEDISP_RIVIERAPRO_TCL  = $(TESTBENCH_MODULE).rivierapro.tcl
# Surfer has no scripting language: this is a flat list of the commands
# its own prompt accepts, replayed once the dump is loaded.
WAVEDISP_SURFER_FILE     = $(TESTBENCH_MODULE).sucl
WAVEDISP_DOT_FILE        = $(TESTBENCH_MODULE).dot

ifeq ($(WAVEDISP_GEN_ARGS),)
WAVEDISP_KWARGS :=
else
WAVEDISP_KWARGS := -a '$(WAVEDISP_GEN_ARGS)'
endif


.PHONY: $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) $(WAVEDISP_RIVIERAPRO_TCL)
.PHONY: $(WAVEDISP_SURFER_FILE) $(WAVEDISP_GTKWAVE_SAV)
.PHONY: waves.wavedisp dot.wavedisp venv.wavedisp clean.wavedisp


HELP_ENTRIES += 'waves.wavedisp|generate the save scripts for every viewer'
HELP_ENTRIES += 'dot.wavedisp|generate and display the dot diagram of the AST'
HELP_ENTRIES += 'venv.wavedisp|create the Python venv and install wavedisp'

# Install wavedisp if it is missing. The venv is only created when we are
# not already inside one.
$(WAVEDISP_BIN):
ifdef VIRTUAL_ENV
	@echo "[wavedisp] Using the active venv $(VIRTUAL_ENV)."
else
	@echo "[wavedisp] Creating Python venv in $(WAVEDISP_VENV_DIR)..."
	python3 -m venv $(WAVEDISP_VENV_DIR)
	$(WAVEDISP_VENV_PIP) install --upgrade pip --quiet
endif
	@echo "[wavedisp] Installing wavedisp from PyPI..."
	$(WAVEDISP_VENV_PIP) install wavedisp --quiet
	@echo "[wavedisp] wavedisp installed successfully."

venv.wavedisp: $(WAVEDISP_BIN)

waves.wavedisp: $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) $(WAVEDISP_RIVIERAPRO_TCL) \
	$(WAVEDISP_SURFER_FILE) $(WAVEDISP_GTKWAVE_SAV)

dot.wavedisp: $(WAVEDISP_DOT_FILE)
	xdot $^

$(WAVEDISP_GTKWAVE_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t gtkwave -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_MODELSIM_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t modelsim -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_RIVIERAPRO_TCL): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t rivierapro -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_SURFER_FILE): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t surfer -o $@ $< $(WAVEDISP_KWARGS)

$(WAVEDISP_DOT_FILE): $(WAVEDISP_FILE) $(WAVEDISP_BIN)
	$(WAVEDISP_BIN) -t dot -o $@ $< $(WAVEDISP_KWARGS)

# The only target that reads the dump: it names its rows from what the run
# actually contains, and records the dump's path, mtime and size. Hence
# -D, and hence regenerating it every time rather than keeping one that
# exists -- a save file held over from an earlier run describes that run,
# and rereading a 473 kB dump costs 40 ms.
#
# The dependency is written as the sim.iverilog target and not as
# $(DUMP_FILE): 26 of the 32 project Makefiles include this file before
# iverilog.mk, where DUMP_FILE is still empty, and prerequisites are
# expanded as the rule is read. A target name survives either order.
$(WAVEDISP_GTKWAVE_SAV): $(WAVEDISP_FILE) $(WAVEDISP_BIN) sim.iverilog
	$(WAVEDISP_BIN) -D $(DUMP_FILE) -t gtkwave-savefile -o $@ $< $(WAVEDISP_KWARGS)

clean:: clean.wavedisp

clean.wavedisp:
	rm -rf $(WAVEDISP_GTKWAVE_TCL) $(WAVEDISP_MODELSIM_TCL) \
		$(WAVEDISP_RIVIERAPRO_TCL) $(WAVEDISP_SURFER_FILE) \
		$(WAVEDISP_GTKWAVE_SAV) $(WAVEDISP_DOT_FILE) __pycache__
