# The ODG_FILE variable must be defined in the top makefile
ifndef ODG_FILES
    $(error Variable ODG_FILES must be declared)
endif

ODG_TO_PDF_FILES = $(ODG_FILES:.odg=.pdf)

all::odgtopdf

odgtopdf: $(ODG_TO_PDF_FILES)

%.pdf: %.odg
	soffice "-env:UserInstallation=file:///tmp/LibO_Conversion__$<" --headless --convert-to pdf $<
	pdfcrop --margins 2 $@ $@

clean::
	rm -rf $(ODG_TO_PDF_FILES)
