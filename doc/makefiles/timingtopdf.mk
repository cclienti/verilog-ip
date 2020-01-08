# The PDF_FILE variable must be defined in the top makefile
ifndef TIMING_FILES
    $(error Variable TIMING_FILES must be declared)
endif

TIMING_TO_PDF_FILES = $(TIMING_FILES:.timing=.pdf)

all:: timingtopdf

timingtopdf: $(TIMING_TO_PDF_FILES)

%.pdf: %.timing
	drawtiming $(DRAWTIMING_FLAGS) --output $(<:.timing=.eps) $<
	epstopdf $(<:.timing=.eps) --outfile=$@
	rm $(<:.timing=.eps)

clean::
	rm -rf $(TIMING_TO_PDF_FILES)
