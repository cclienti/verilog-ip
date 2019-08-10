# Datasheet Latex Makefile
# Copyright (C) 2016 Christophe Clienti - All Rights Reserved

MKFILE_PATH = $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR = $(dir $(MKFILE_PATH))
LOGO_DIR    = $(CURRENT_DIR)../logo

pdflatex: prologue pdflatex_logo $(PDF_FILE)

prologue::

pdflatex_logo:
	@$(MAKE) -C $(LOGO_DIR)

$(PDF_FILE): $(MAIN_TEX_FILE) $(DEP_TEX_FILES) $(BIB_FILE)
	@TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $<
	@test -s $(BIB_FILE) && bibtex $(notdir $(MAIN_TEX_FILE:.tex=))  || echo "no bib to process"
	@TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $<
	@TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $<
	@mv $(notdir $(MAIN_TEX_FILE:.tex=.pdf)) $(PDF_FILE)

clean::
	@rm -rf *.pdf *.toc *.aux *.log *.out *.bbl *.blg

print-%:
	@echo $* = $($*)
