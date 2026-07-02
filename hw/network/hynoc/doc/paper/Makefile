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

# arXiv source tarball: main .tex, section inputs, references.bib, and only
# the PDF figures actually used -- no .odg/.eps sources, no build artifacts,
# no main.pdf. The generated main.bbl is intentionally NOT bundled: arXiv
# prefers to run BibTeX on references.bib itself (IEEEtran.bst is standard on
# its TeX Live).
arxiv: $(PAPER).pdf
	@rm -f $(ARXIV)
	tar czf $(ARXIV) $(PAPER).tex references.bib \
	    $(SECTIONS) $(FIGURES)
	@echo "--- $(ARXIV) contents ---"
	@tar tzf $(ARXIV)

clean:
	rm -f $(PAPER).aux $(PAPER).bbl $(PAPER).blg \
	      $(PAPER).log $(PAPER).out $(PAPER).toc \
	      sections/*.aux

distclean: clean
	rm -f $(PAPER).pdf $(ARXIV)
