# The PDF_FILE variable must be defined in the top makefile
ifndef PDF_FILES
    $(error Variable PDF_FILES must be declared)
endif

PDF_TO_EPS_FILES = $(PDF_FILES:.pdf=.eps)

all::pdftoeps

pdftoeps: $(PDF_TO_EPS_FILES)

%.eps: %.pdf
	pdftops -eps $< $@

clean::
	rm -rf $(PDF_TO_EPS_FILES)
