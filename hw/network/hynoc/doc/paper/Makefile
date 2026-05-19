PAPER    = main
LATEX    = pdflatex
BIBTEX   = bibtex

FIGDIR   = ../datasheet/figures

FIGURES  = $(FIGDIR)/hynoc_noc_overview.pdf        \
           $(FIGDIR)/hynoc_router_data_arch.pdf     \
           $(FIGDIR)/hynoc_router_control_arch.pdf  \
           $(FIGDIR)/hynoc_hops_encoding.pdf

SECTIONS = sections/abstract.tex        \
           sections/introduction.tex    \
           sections/related_work.tex    \
           sections/architecture.tex    \
           sections/switching.tex       \
           sections/target.tex          \
           sections/implementation.tex  \
           sections/conclusion.tex

.PHONY: all clean distclean

all: $(PAPER).pdf

$(PAPER).pdf: $(PAPER).tex $(SECTIONS) references.bib $(FIGURES)
	$(LATEX)  $(PAPER)
	$(BIBTEX) $(PAPER)
	$(LATEX)  $(PAPER)
	$(LATEX)  $(PAPER)

clean:
	rm -f $(PAPER).aux $(PAPER).bbl $(PAPER).blg \
	      $(PAPER).log $(PAPER).out $(PAPER).toc \
	      sections/*.aux

distclean: clean
	rm -f $(PAPER).pdf
