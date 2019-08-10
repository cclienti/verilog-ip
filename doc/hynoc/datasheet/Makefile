MAIN_TEX_FILE     = ../../resources/templates/datasheet/base.tex
PDF_FILE          = wavecruncher_hynoc_datasheet.pdf
DEP_TEX_FILES     = brief.tex features.tex iptitle.tex iptable.tex content.tex references.tex
BIB_FILE          = references.bib
EXTRA_TEXINPUTS   =

all: pdflatex

prologue::
	$(MAKE) -C figures

clean::
	$(MAKE) -C figures clean

include ../../resources/makefiles/pdflatex.mk
