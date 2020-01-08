# The PDF_FILE variable must be defined in the top makefile
ifndef UML_FILES
    $(error Variable UML_FILES must be declared)
endif

UML_TO_PDF_FILES = $(UML_FILES:.uml=.pdf)

all:: umltopdf

umltopdf: $(UML_TO_PDF_FILES)

%.pdf: %.uml
	plantuml -teps $<
	epstopdf $(<:.uml=.eps) --outfile=$@
	rm $(<:.uml=.eps)

clean::
	rm -rf $(UML_TO_PDF_FILES)
