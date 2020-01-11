ROOT_DIR         = $(shell git rev-parse --show-toplevel)/doc
MAIN_TEX_FILE    = $(ROOT_DIR)/templates/datasheet/base.tex
PDF_BASENAME     = test
DEP_TEX_FILES    = brief.tex features.tex iptitle.tex iptable.tex content.tex references.tex
BIB_FILE         = references.bib
EXTRA_TEXINPUTS  =

include $(ROOT_DIR)/makefiles/pdflatex.mk
