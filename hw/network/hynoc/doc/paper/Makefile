PAPER    = main
LATEX    = pdflatex
BIBTEX   = bibtex

FIGDIR   = ./figures

FIGURES  = $(wildcard $(FIGDIR)/*.pdf)

ARXIV    = $(PAPER)-arxiv.tar.gz

SECTIONS = sections/abstract.tex        \
           sections/introduction.tex    \
           sections/related_work.tex    \
           sections/architecture.tex    \
           sections/switching.tex       \
           sections/target.tex          \
           sections/implementation.tex  \
           sections/evaluation.tex      \
           sections/conclusion.tex

.PHONY: all clean distclean arxiv

all: $(PAPER).pdf

$(PAPER).pdf: $(PAPER).tex $(SECTIONS) references.bib $(FIGURES)
	$(LATEX)  $(PAPER)
	$(BIBTEX) $(PAPER)
	$(LATEX)  $(PAPER)
	$(LATEX)  $(PAPER)

# arXiv source tarball: main .tex, section inputs, the .bib and generated
# .bbl (arXiv does not reliably re-run BibTeX), and only the PDF figures that
# are actually used -- no .odg/.eps sources, no build artifacts, no main.pdf.
arxiv: $(PAPER).pdf
	@rm -f $(ARXIV)
	tar czf $(ARXIV) $(PAPER).tex $(PAPER).bbl references.bib \
	    $(SECTIONS) $(FIGURES)
	@echo "--- $(ARXIV) contents ---"
	@tar tzf $(ARXIV)

clean:
	rm -f $(PAPER).aux $(PAPER).bbl $(PAPER).blg \
	      $(PAPER).log $(PAPER).out $(PAPER).toc \
	      sections/*.aux

distclean: clean
	rm -f $(PAPER).pdf $(ARXIV)
