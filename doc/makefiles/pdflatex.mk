# Datasheet Latex Makefile
# Copyright (C) 2016 Christophe Clienti - All Rights Reserved

LOGO_DIR    ?= $(ROOT_DIR)/logo
PDF_VERSION ?= $(shell grep IPRev iptitle.tex | cut -f 3 -d '{' | cut -f 1 -d '}' | tr -d ' ' | tr -s '.' '_')
PDF_FILE    ?= wavecruncher_$(PDF_BASENAME)_v$(PDF_VERSION).pdf
PROLOGUE    ?=

pdflatex: $(PDF_FILE)


pdflatex_logo.done: $(LOGO_DIR)/logo.py
	@$(MAKE) -C $(LOGO_DIR) all
	touch pdflatex_logo.done


$(PDF_FILE): $(MAIN_TEX_FILE) $(DEP_TEX_FILES) $(BIB_FILE) pdflatex_logo.done $(PROLOGUE)
	TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $(MAIN_TEX_FILE) $(DEP_TEX_FILES) $(BIB_FILE)
	test -s $(BIB_FILE) && bibtex $(notdir $(MAIN_TEX_FILE:.tex=))  || echo "no bib to process"
	TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $(MAIN_TEX_FILE) $(DEP_TEX_FILES) $(BIB_FILE)
	TEXINPUTS=.:$(LOGO_DIR):$(EXTRA_TEXINPUTS):$$TEXINPUTS pdflatex $(MAIN_TEX_FILE) $(DEP_TEX_FILES) $(BIB_FILE)
	mv $(notdir $(MAIN_TEX_FILE:.tex=.pdf)) $(PDF_FILE)


clean::
	@$(MAKE) -C $(LOGO_DIR) clean
	@rm -f *.pdf *.toc *.aux *.log *.out *.bbl *.blg *.brf *.lot *.lof
	@rm -f pdflatex_logo.done $(PROLOGUE)


print-%:
	@echo $* = $($*)
