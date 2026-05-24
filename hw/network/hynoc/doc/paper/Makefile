PAPER    = main
LATEX    = pdflatex
BIBTEX   = bibtex

FIGDIR   = ./figures

FIGURES  = $(wildcard $(FIGDIR)/*.pdf)

SECTIONS = sections/abstract.tex        \
           sections/introduction.tex    \
           sections/related_work.tex    \
           sections/architecture.tex    \
           sections/switching.tex       \
           sections/target.tex          \
           sections/implementation.tex  \
           sections/evaluation.tex      \
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
