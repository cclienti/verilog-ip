# The PDF_FILE variable must be defined in the top makefile
ifndef DOT_FILES
    $(error Variable DOT_FILES must be declared)
endif

DOT_TO_PDF_FILES = $(DOT_FILES:.dot=.pdf)

all:: dottopdf

dottopdf: $(DOT_TO_PDF_FILES)

%.pdf: %.dot
	dot $(DOT_FLAGS) -Tps $< -o $(<:.dot=.ps)
	epstopdf $(<:.dot=.ps) --outfile=$@
	rm $(<:.dot=.ps)

clean::
	rm -rf $(DOT_TO_PDF_FILES)
