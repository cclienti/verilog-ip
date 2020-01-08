ROOT_DIR         = $(shell git rev-parse --show-toplevel)/doc
MAIN_TEX_FILE    = $(ROOT_DIR)/templates/datasheet/base.tex
PDF_FILE         = test.pdf
DEP_TEX_FILES    = brief.tex features.tex iptitle.tex iptable.tex content.tex
BIB_FILE         = references.bib
EXTRA_TEXINPUTS  =

include $(ROOT_DIR)/makefiles/pdflatex.mk
