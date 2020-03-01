ROOT_DIR         = $(shell git rev-parse --show-toplevel)/doc
MAIN_TEX_FILE    = $(ROOT_DIR)/templates/datasheet/base.tex
PDF_BASENAME     = hynoc
DEP_TEX_FILES    = brief.tex features.tex iptitle.tex iptable.tex content.tex revisions.tex references.tex
PROLOGUE         = prologue.done
BIB_FILE         = references.bib
EXTRA_TEXINPUTS  =

all: pdflatex

$(PROLOGUE): $(wildcard figures/*.odg)
	$(MAKE) -C figures
	touch $@

clean::
	$(MAKE) -C figures clean
	rm -f $(PROLOGUE)

include $(ROOT_DIR)/makefiles/pdflatex.mk
